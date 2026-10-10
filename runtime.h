/* Haste runtime — included verbatim at the top of every generated C file. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdbool.h>
#include <setjmp.h>
#include <math.h>
#include <ctype.h>
#include <time.h>
#include <errno.h>
#include <stdint.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

typedef const char *hs_str;

/* ---- memory: a mark-and-sweep garbage collector ----
   A collection marks every block reachable from the main thread's stack and registers, then follows the
   pointers inside those blocks; everything else is freed. The stack is scanned conservatively (any word
   that points into a block keeps it), so generated code needs no bookkeeping, and cycles are no problem.
   "Atomic" blocks (text, numbers) hold no pointers and are not scanned. No collection runs while a
   parallel for is running, so worker threads never have to be stopped.
   Small blocks come from 64 KB pages, each page holding blocks of one size: a pointer finds its block by
   rounding down to the page, and a freed block just goes back on its size's free list. Big blocks use malloc. */
#define HS_PAGE ((size_t)1 << 16)
#define HS_CHUNK (16 * HS_PAGE)                               /* pages are taken from the system 16 at a time */
#define HS_SMALL 2048
#ifndef HS_GC_MIN
#define HS_GC_MIN ((size_t)8 << 20)                         /* collect after at least 8 MB of new blocks */
#endif
enum { HS_USED = 1, HS_MARK = 2, HS_ATOMIC = 4 };
static const unsigned short hs_sizes[] = { 16, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024, 1536, 2048 };
#define HS_NCLASS (sizeof hs_sizes / sizeof hs_sizes[0])

typedef struct { size_t size, nslots; char *first; unsigned char state[]; } hs_page;   /* size 0: page unused */
typedef struct { size_t size; unsigned char state; } hs_big;
#define HS_BIGHDR ((sizeof(hs_big) + 15) & ~(size_t)15)

static void *hs_free[HS_NCLASS];                              /* free blocks of each size, linked through their first word */
static char **hs_chunks, *hs_chunk_next, *hs_chunk_end;       /* hs_chunks: page-aligned starts, sorted */
static hs_big **hs_bigs;
static size_t hs_nchunks, hs_nbigs, hs_capbigs, hs_since, hs_limit = HS_GC_MIN;
static uintptr_t hs_lo = UINTPTR_MAX, hs_hi;                  /* every block lies in [hs_lo, hs_hi) */
static char *hs_stack_base;                                   /* set in main */
static int hs_par_depth;                                      /* > 0 while a parallel for runs */
static char hs_lock;
static _Thread_local hs_str hs_error = "";
static _Thread_local hs_str hs_len_last;                      /* hs_len's cache; reset when blocks are freed */
static void hs_gc_collect(void);

static void hs_oom(void) { fputs("out of memory\n", stderr); exit(2); }
static void hs_span(uintptr_t a, uintptr_t b) { if (a < hs_lo) hs_lo = a; if (b > hs_hi) hs_hi = b; }

static void hs_new_page(size_t c) {
    if (hs_chunk_next == hs_chunk_end) {
        char *raw = malloc(HS_CHUNK + HS_PAGE);               /* never freed: pages are reused instead */
        if (!raw) hs_oom();
        char *start = (char *)(((uintptr_t)raw + HS_PAGE - 1) & ~(uintptr_t)(HS_PAGE - 1));
        for (char *p = start; p < start + HS_CHUNK; p += HS_PAGE) ((hs_page *)p)->size = 0;
        hs_chunks = realloc(hs_chunks, sizeof *hs_chunks * (hs_nchunks + 1));
        if (!hs_chunks) hs_oom();
        size_t i = hs_nchunks++;
        while (i && hs_chunks[i - 1] > start) { hs_chunks[i] = hs_chunks[i - 1]; i--; }
        hs_chunks[i] = start;
        hs_chunk_next = start;
        hs_chunk_end = start + HS_CHUNK;
        hs_span((uintptr_t)start, (uintptr_t)hs_chunk_end);
    }
    hs_page *pg = (hs_page *)hs_chunk_next;
    hs_chunk_next += HS_PAGE;
    size_t size = hs_sizes[c];
    pg->nslots = (HS_PAGE - sizeof(hs_page) - 16) / (size + 1);
    pg->first = (char *)(((uintptr_t)(pg->state + pg->nslots) + 15) & ~(uintptr_t)15);
    memset(pg->state, 0, pg->nslots);
    pg->size = size;
    for (size_t i = pg->nslots; i-- > 0;) {
        void **slot = (void **)(pg->first + i * size);
        *slot = hs_free[c];
        hs_free[c] = slot;
    }
}

static void *hs_alloc_kind(size_t n, int atomic) {
    if (hs_since > hs_limit && hs_stack_base && !__atomic_load_n(&hs_par_depth, __ATOMIC_ACQUIRE)) hs_gc_collect();
    bool par = __atomic_load_n(&hs_par_depth, __ATOMIC_ACQUIRE) > 0;
    if (par) while (__atomic_test_and_set(&hs_lock, __ATOMIC_ACQUIRE)) {}
    void *p;
    if (n <= HS_SMALL) {
        size_t c = 0;
        while (hs_sizes[c] < n) c++;
        if (!hs_free[c]) hs_new_page(c);
        p = hs_free[c];
        hs_free[c] = *(void **)p;
        hs_page *pg = (hs_page *)((uintptr_t)p & ~(uintptr_t)(HS_PAGE - 1));
        pg->state[((char *)p - pg->first) / pg->size] = HS_USED | (atomic ? HS_ATOMIC : 0);
        n = pg->size;
        memset(p, 0, n);
    } else {
        hs_big *b = calloc(1, HS_BIGHDR + n);
        if (!b) hs_oom();
        b->size = n;
        b->state = HS_USED | (atomic ? HS_ATOMIC : 0);
        if (hs_nbigs == hs_capbigs) {
            hs_capbigs = hs_capbigs ? hs_capbigs * 2 : 64;
            hs_bigs = realloc(hs_bigs, sizeof *hs_bigs * hs_capbigs);
            if (!hs_bigs) hs_oom();
        }
        hs_bigs[hs_nbigs++] = b;
        p = (char *)b + HS_BIGHDR;
        hs_span((uintptr_t)p, (uintptr_t)p + n);
    }
    hs_since += n;
    if (par) __atomic_clear(&hs_lock, __ATOMIC_RELEASE);
    return p;
}
static void *hs_alloc(size_t n) { return hs_alloc_kind(n, 0); }          /* may hold pointers */
static void *hs_alloc_atomic(size_t n) { return hs_alloc_kind(n, 1); }   /* never holds pointers */

/* A bigger copy of an array; the old one becomes garbage. */
static void *hs_grow(void *old, size_t used, size_t n, int atomic) {
    void *p = hs_alloc_kind(n, atomic);
    if (old) memcpy(p, old, used);
    return p;
}

typedef struct { const char *p; size_t n; } hs_span_t;
static hs_span_t *hs_marks;
static size_t hs_nmarks, hs_capmarks;

static int hs_big_cmp(const void *a, const void *b) {
    uintptr_t x = (uintptr_t)*(hs_big *const *)a, y = (uintptr_t)*(hs_big *const *)b;
    return x < y ? -1 : x > y;
}
/* Mark the block p points into, if any, and queue it to have its own pointers followed. */
static void hs_gc_consider(uintptr_t p) {
    if (p < hs_lo || p >= hs_hi) return;
    unsigned char *st;
    const char *start;
    size_t n;
    size_t lo = 0, hi = hs_nchunks;                           /* is p inside one of the chunks of pages? */
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if ((uintptr_t)hs_chunks[mid] + HS_CHUNK <= p) lo = mid + 1; else hi = mid;
    }
    if (lo < hs_nchunks && (uintptr_t)hs_chunks[lo] <= p) {
        hs_page *pg = (hs_page *)(p & ~(uintptr_t)(HS_PAGE - 1));
        if (!pg->size || p < (uintptr_t)pg->first) return;
        size_t i = (p - (uintptr_t)pg->first) / pg->size;
        if (i >= pg->nslots) return;
        st = &pg->state[i];
        start = pg->first + i * pg->size;
        n = pg->size;
    } else {
        lo = 0, hi = hs_nbigs;                                /* the last big block starting at or before p */
        while (hi - lo > 1) {
            size_t mid = (lo + hi) / 2;
            if ((uintptr_t)hs_bigs[mid] <= p) lo = mid; else hi = mid;
        }
        if (!hs_nbigs || (uintptr_t)hs_bigs[lo] + HS_BIGHDR > p || p > (uintptr_t)hs_bigs[lo] + HS_BIGHDR + hs_bigs[lo]->size) return;
        st = &hs_bigs[lo]->state;
        start = (const char *)hs_bigs[lo] + HS_BIGHDR;
        n = hs_bigs[lo]->size;
    }
    if ((*st & (HS_USED | HS_MARK)) != HS_USED) return;      /* free, or already marked */
    *st |= HS_MARK;
    if (*st & HS_ATOMIC) return;
    if (hs_nmarks == hs_capmarks) {
        hs_capmarks = hs_capmarks ? hs_capmarks * 2 : 1024;
        hs_marks = realloc(hs_marks, sizeof *hs_marks * hs_capmarks);
        if (!hs_marks) hs_oom();
    }
    hs_marks[hs_nmarks++] = (hs_span_t){ start, n };
}
static void hs_gc_scan(const char *b, const char *e) {
    b = (const char *)(((uintptr_t)b + sizeof(void *) - 1) & ~(uintptr_t)(sizeof(void *) - 1));
    for (; b + sizeof(void *) <= e; b += sizeof(void *)) {
        uintptr_t p;
        memcpy(&p, b, sizeof p);
        hs_gc_consider(p);
    }
}
/* Called after setjmp has copied the registers into the caller's frame, so they are on the stack too. */
static __attribute__((noinline)) void hs_gc_scan_stack(void) {
    volatile char here = 0;
    hs_gc_scan((const char *)&here, hs_stack_base);
}
static __attribute__((noinline)) void hs_gc_collect(void) {
    qsort(hs_bigs, hs_nbigs, sizeof *hs_bigs, hs_big_cmp);
    jmp_buf regs;
    setjmp(regs);
    hs_gc_scan_stack();
    hs_gc_consider((uintptr_t)hs_error);
    while (hs_nmarks) {
        hs_span_t s = hs_marks[--hs_nmarks];
        hs_gc_scan(s.p, s.p + s.n);
    }
    size_t live = 0;                                          /* sweep: unmarked blocks go back on the free lists */
    for (size_t c = 0; c < HS_NCLASS; c++) hs_free[c] = NULL;
    for (size_t k = hs_nchunks; k-- > 0;)
        for (char *a = hs_chunks[k] + HS_CHUNK - HS_PAGE; a >= hs_chunks[k]; a -= HS_PAGE) {
            hs_page *pg = (hs_page *)a;
            if (!pg->size) continue;
            size_t c = 0;
            while (hs_sizes[c] != pg->size) c++;
            for (size_t i = pg->nslots; i-- > 0;) {
                if (pg->state[i] & HS_MARK) { pg->state[i] &= (unsigned char)~HS_MARK; live += pg->size; continue; }
                pg->state[i] = 0;
                void **slot = (void **)(pg->first + i * pg->size);
                *slot = hs_free[c];
                hs_free[c] = slot;
            }
        }
    size_t kept = 0;
    for (size_t i = 0; i < hs_nbigs; i++) {
        hs_big *b = hs_bigs[i];
        if (b->state & HS_MARK) { b->state &= (unsigned char)~HS_MARK; live += b->size; hs_bigs[kept++] = b; }
        else free(b);
    }
    hs_nbigs = kept;
    hs_since = 0;
    hs_limit = live > HS_GC_MIN ? live : HS_GC_MIN;           /* the heap stays under about twice what is live */
    hs_len_last = NULL;
}

static hs_str hs_fmt(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *s = hs_alloc_atomic((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(s, (size_t)n + 1, fmt, ap);
    va_end(ap);
    return s;
}

/* ---- errors: try/catch is a stack of jump buffers ---- */
static _Thread_local jmp_buf *hs_try_stack[64];
static _Thread_local int hs_try_depth = 0;

static void hs_try_push(jmp_buf *jb) {
    if (hs_try_depth == 64) { fputs("try nested too deeply\n", stderr); exit(2); }
    hs_try_stack[hs_try_depth++] = jb;
}
static void hs_try_pop(void) { hs_try_depth--; }

static void hs_raise(hs_str msg) {
    hs_error = msg;
    if (hs_try_depth > 0) longjmp(*hs_try_stack[--hs_try_depth], 1);
    fprintf(stderr, "Unhandled error: %s\n", msg);
    exit(1);
}

static void hs_require_fail(hs_str prop, hs_str value, hs_str rule) {
    hs_raise(hs_fmt("%s cannot be %s (requires %s)", prop, value, rule));
}

/* ---- core operations ---- */
static void hs_print(hs_str s) { puts(s); }
static hs_str hs_cat(hs_str a, hs_str b) { return hs_fmt("%s%s", a, b); }
static bool hs_eq(hs_str a, hs_str b) { return strcmp(a, b) == 0; }

static long long hs_idiv(long long a, long long b) {
    if (b == 0) hs_raise("division by zero");
    return a / b;
}
static long long hs_imod(long long a, long long b) {
    if (b == 0) hs_raise("division by zero");
    return a % b;
}

/* ---- helpers the standard library binds to with `extern fn` ---- */
static hs_str hs_upper(hs_str s) {
    char *r = (char *)hs_fmt("%s", s);
    for (char *p = r; *p; p++) *p = (char)toupper((unsigned char)*p);
    return r;
}
static hs_str hs_lower(hs_str s) {
    char *r = (char *)hs_fmt("%s", s);
    for (char *p = r; *p; p++) *p = (char)tolower((unsigned char)*p);
    return r;
}
static hs_str hs_pad_right(hs_str s, long long width) { return hs_fmt("%-*s", (int)width, s); }
static hs_str hs_repeat(hs_str s, long long count) {
    size_t n = strlen(s);
    char *r = hs_alloc_atomic(n * (size_t)(count > 0 ? count : 0) + 1);
    for (long long i = 0; i < count; i++) memcpy(r + n * (size_t)i, s, n);
    return r;
}
static bool hs_starts_with(hs_str s, hs_str prefix) { return strncmp(s, prefix, strlen(prefix)) == 0; }

/* ---- files and time (used by System and Time) ---- */
static FILE *hs_files[16];
static long long hs_file_open(hs_str path) {
    for (int i = 0; i < 16; i++)
        if (!hs_files[i]) {
            if (!(hs_files[i] = fopen(path, "wb"))) hs_raise(hs_fmt("cannot write %s", path));
            return i;
        }
    hs_raise("too many open files");
    return -1;
}
static void hs_file_byte(long long f, long long b) { fputc((int)(b & 255), hs_files[f]); }
static void hs_file_close(long long f) { fclose(hs_files[f]); hs_files[f] = NULL; }
/* Wall-clock seconds from a fixed point; use differences. */
static double hs_elapsed(void) {
#ifdef _WIN32
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart / (double)f.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

/* ---- reading files and characters (used by System.ReadText and Text) ---- */
static hs_str hs_read_file(hs_str path) {
    FILE *f = fopen(path, "rb");
    if (!f) hs_raise(hs_fmt("cannot read %s", path));
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *s = hs_alloc_atomic((size_t)n + 1);
    if (fread(s, 1, (size_t)n, f) != (size_t)n) hs_raise(hs_fmt("cannot read %s", path));
    s[n] = 0;
    fclose(f);
    return s;
}
/* Strings are immutable, so the length of the last string seen can be cached
   (the collector resets the cache, because a freed string's address can be reused). */
static size_t hs_len(hs_str s) {
    static _Thread_local size_t len;
    if (s != hs_len_last) { hs_len_last = s; len = strlen(s); }
    return len;
}
static long long hs_code(hs_str s, long long i) {
    if (i < 0 || (size_t)i >= hs_len(s)) hs_raise(hs_fmt("character %lld is outside the string", i));
    return (unsigned char)s[i];
}
static hs_str hs_sub(hs_str s, long long start, long long count) {
    size_t n = hs_len(s);
    if (start < 0 || count < 0 || (size_t)(start + count) > n) hs_raise("substring is outside the string");
    char *r = hs_alloc_atomic((size_t)count + 1);
    memcpy(r, s + start, (size_t)count);
    return r;
}
/* Index of the next character with this code at or after `from`, or the length if there is none. */
static long long hs_find(hs_str s, long long code, long long from) {
    size_t n = hs_len(s);
    if (from < 0) from = 0;
    if ((size_t)from >= n) return (long long)n;
    const char *p = memchr(s + from, (int)code, n - (size_t)from);
    return p ? (long long)(p - s) : (long long)n;
}

/* ---- parallel for: worker threads take iterations from a shared counter ---- */
typedef struct { void (*fn)(void *, long long); void *ctx; long long n, next; } hs_job;

static void hs_work(hs_job *j) {
    long long i;
    while ((i = __atomic_fetch_add(&j->next, 1, __ATOMIC_RELAXED)) < j->n) j->fn(j->ctx, i);
}
#ifdef _WIN32
static DWORD WINAPI hs_thread(LPVOID p) { hs_work(p); return 0; }
static int hs_cores(void) { SYSTEM_INFO si; GetSystemInfo(&si); return (int)si.dwNumberOfProcessors; }
#else
static void *hs_thread(void *p) { hs_work(p); return NULL; }
static int hs_cores(void) { return (int)sysconf(_SC_NPROCESSORS_ONLN); }
#endif

static void hs_parallel(long long n, void (*fn)(void *, long long), void *ctx) {
    hs_job j = { fn, ctx, n, 0 };
    __atomic_add_fetch(&hs_par_depth, 1, __ATOMIC_RELEASE);      /* no collecting while workers run */
    int t = hs_cores();
    if (t > 64) t = 64;
    if (t > n) t = (int)n;
    if (t < 1) t = 1;
#ifdef _WIN32
    HANDLE th[64];
    for (int k = 1; k < t; k++) th[k] = CreateThread(NULL, 0, hs_thread, &j, 0, NULL);
    hs_work(&j);
    for (int k = 1; k < t; k++) { WaitForSingleObject(th[k], INFINITE); CloseHandle(th[k]); }
#else
    pthread_t th[64];
    for (int k = 1; k < t; k++) pthread_create(&th[k], NULL, hs_thread, &j);
    hs_work(&j);
    for (int k = 1; k < t; k++) pthread_join(th[k], NULL);
#endif
    __atomic_sub_fetch(&hs_par_depth, 1, __ATOMIC_RELEASE);
}

/* ---- command-line switches:  --width 640  (also --width=640, -width 640; /width:640 on Windows only,
        because elsewhere a leading / starts a file path) ---- */
#ifdef _WIN32
#define HS_SLASH(c) ((c) == '/')
#else
#define HS_SLASH(c) 0
#endif
typedef struct { const char *name; int kind; void *ptr; const char *help, *def, *rule; } hs_switch;
static const char *hs_kind_names[] = { "number", "decimal", "text", "on/off" };

static bool hs_same(const char *a, const char *b, size_t n) {      /* case-insensitive, b has length n */
    for (size_t i = 0; i < n; i++, a++)
        if (!*a || tolower((unsigned char)*a) != tolower((unsigned char)b[i])) return false;
    return *a == 0;
}
static hs_str hs_lowered(const char *s) { return hs_lower(s); }

static void hs_switch_fail(hs_switch *s) {
    hs_str v = s->kind == 0 ? hs_fmt("%lld", *(long long *)s->ptr) : s->kind == 1 ? hs_fmt("%g", *(double *)s->ptr)
             : s->kind == 2 ? hs_fmt("\"%s\"", *(hs_str *)s->ptr) : (*(bool *)s->ptr ? "true" : "false");
    fprintf(stderr, "--%s cannot be %s (requires %s)\n", hs_lowered(s->name), v, s->rule);
    exit(1);
}
static void hs_switch_usage(const char *prog, hs_switch *s, int n) {
    printf("Usage: %s [switches]\n\n", prog);
    for (int i = 0; i < n; i++) {
        printf("  --%-12s %-8s %s%s(default %s", hs_lowered(s[i].name), hs_kind_names[s[i].kind],
               s[i].help, *s[i].help ? " " : "", s[i].def);
        if (*s[i].rule) printf(", must satisfy %s", s[i].rule);
        printf(")\n");
    }
    exit(0);
}
static bool hs_bool_word(const char *v) {
    static const char *words[] = { "true", "false", "yes", "no", "on", "off", "1", "0" };
    for (int k = 0; k < 8; k++) if (hs_same(v, words[k], strlen(words[k]))) return true;
    return false;
}
static void hs_switches(int argc, char **argv, hs_switch *s, int n) {
    const char *prog = argv[0];
    for (const char *p = argv[0]; *p; p++) if (*p == '/' || *p == '\\') prog = p + 1;
    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "-h") || !strcmp(a, "--help") || !strcmp(a, "-?") || (HS_SLASH(a[0]) && !strcmp(a, "/?"))) hs_switch_usage(prog, s, n);
        if (a[0] != '-' && !HS_SLASH(a[0])) {
            fprintf(stderr, "unexpected '%s'; run with --help to see the switches\n", a); exit(1);
        }
        const char *name = a + (a[0] == '-' && a[1] == '-' ? 2 : 1);
        size_t len = strcspn(name, "=:");
        const char *value = name[len] ? name + len + 1 : NULL;
        hs_switch *w = NULL;
        for (int k = 0; k < n; k++) if (hs_same(s[k].name, name, len)) w = &s[k];
        if (!w) { fprintf(stderr, "unknown switch '%s'; run with --help to see the switches\n", a); exit(1); }
        if (!value) {
            /* An on/off switch alone means on; a following true/false/yes/no/on/off/1/0 is its value
               (there are no plain arguments, so that word can mean nothing else). */
            if (w->kind == 3) value = (i + 1 < argc && hs_bool_word(argv[i + 1])) ? argv[++i] : "true";
            else if (i + 1 < argc) value = argv[++i];
            else { fprintf(stderr, "--%s needs a value\n", hs_lowered(w->name)); exit(1); }
        }
        char *end = NULL;
        switch (w->kind) {
        case 0: *(long long *)w->ptr = strtoll(value, &end, 10); break;
        case 1: *(double *)w->ptr = strtod(value, &end); break;
        case 2: *(hs_str *)w->ptr = value; end = ""; break;
        case 3:
            if (hs_same(value, "true", 4) || hs_same(value, "yes", 3) || hs_same(value, "on", 2) || !strcmp(value, "1"))
                *(bool *)w->ptr = true, end = "";
            else if (hs_same(value, "false", 5) || hs_same(value, "no", 2) || hs_same(value, "off", 3) || !strcmp(value, "0"))
                *(bool *)w->ptr = false, end = "";
            break;
        }
        if (!end || end == value || *end) {
            static const char *need[] = { "a whole number", "a number", "text", "true or false" };
            fprintf(stderr, "--%s needs %s, not '%s'\n", hs_lowered(w->name), need[w->kind], value);
            exit(1);
        }
    }
}

/* ---- text and file basics (Text.Split/Join/Trim/..., System.ReadLines/WriteText/...) ----
   Functions that return or take lists use the same layout the compiler gives [string]. */
typedef struct { hs_str *items; long long count, cap; } hs_strs;

static void hs_strs_add(hs_strs *l, hs_str s) {
    if (l->count == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 8;
        l->items = hs_grow(l->items, sizeof(hs_str) * (size_t)l->count, sizeof(hs_str) * (size_t)l->cap, 0);
    }
    l->items[l->count++] = s;
}
static hs_str hs_dup(const char *p, size_t n) {
    char *r = hs_alloc_atomic(n + 1);
    memcpy(r, p, n);
    return r;
}
/* First occurrence of pat (length m) in [b, e), or NULL. */
static const char *hs_memfind(const char *b, const char *e, const char *pat, size_t m) {
    if (m == 0) return b;
    while ((size_t)(e - b) >= m) {
        const char *p = memchr(b, pat[0], (size_t)(e - b) - m + 1);
        if (!p) return NULL;
        if (!memcmp(p, pat, m)) return p;
        b = p + 1;
    }
    return NULL;
}
static long long hs_find_text(hs_str s, hs_str part, long long from) {
    size_t n = hs_len(s);
    if (from < 0) from = 0;
    if ((size_t)from > n) return (long long)n;
    const char *p = hs_memfind(s + from, s + n, part, strlen(part));
    return p ? (long long)(p - s) : (long long)n;
}
static bool hs_contains(hs_str s, hs_str part) { return hs_memfind(s, s + strlen(s), part, strlen(part)) != NULL; }

static void *hs_split(hs_str s, hs_str sep) {
    hs_strs *l = hs_alloc(sizeof *l);
    size_t m = strlen(sep);
    const char *b = s, *e = s + strlen(s), *p;
    if (m == 0) { hs_strs_add(l, hs_dup(s, (size_t)(e - b))); return l; }
    while ((p = hs_memfind(b, e, sep, m))) { hs_strs_add(l, hs_dup(b, (size_t)(p - b))); b = p + m; }
    hs_strs_add(l, hs_dup(b, (size_t)(e - b)));
    return l;
}
static hs_str hs_join(void *list, hs_str sep) {
    hs_strs *l = list;
    size_t m = strlen(sep), total = 0;
    for (long long i = 0; i < l->count; i++) total += strlen(l->items[i]) + (i ? m : 0);
    char *r = hs_alloc_atomic(total + 1), *w = r;
    for (long long i = 0; i < l->count; i++) {
        if (i) { memcpy(w, sep, m); w += m; }
        size_t k = strlen(l->items[i]);
        memcpy(w, l->items[i], k); w += k;
    }
    return r;
}
static hs_str hs_trim(hs_str s) {
    const char *b = s, *e = s + strlen(s);
    while (b < e && isspace((unsigned char)*b)) b++;
    while (e > b && isspace((unsigned char)e[-1])) e--;
    return hs_dup(b, (size_t)(e - b));
}
static hs_str hs_replace(hs_str s, hs_str old, hs_str rep) {
    size_t m = strlen(old), r = strlen(rep), n = strlen(s), count = 0;
    if (m == 0) return s;
    const char *e = s + n, *b, *p;
    for (b = s; (p = hs_memfind(b, e, old, m)); b = p + m) count++;
    char *out = hs_alloc_atomic(n + count * r - count * m + 1), *w = out;
    for (b = s; (p = hs_memfind(b, e, old, m)); b = p + m) {
        memcpy(w, b, (size_t)(p - b)); w += p - b;
        memcpy(w, rep, r); w += r;
    }
    memcpy(w, b, (size_t)(e - b));
    return out;
}
static long long hs_to_int(hs_str s) {
    char *end;
    errno = 0;
    long long v = strtoll(s, &end, 10);
    while (isspace((unsigned char)*end)) end++;
    if (end == s || *end || errno) hs_raise(hs_fmt("\"%s\" is not a whole number", s));
    return v;
}
static double hs_to_float(hs_str s) {
    char *end;
    double v = strtod(s, &end);
    while (isspace((unsigned char)*end)) end++;
    if (end == s || *end) hs_raise(hs_fmt("\"%s\" is not a number", s));
    return v;
}
static void *hs_read_lines(hs_str path) {
    hs_str text = hs_read_file(path);
    hs_strs *l = hs_alloc(sizeof *l);
    const char *b = text, *e = text + strlen(text), *p;
    while (b < e) {
        p = memchr(b, '\n', (size_t)(e - b));
        const char *end = p ? p : e;
        size_t n = (size_t)(end - b);
        if (n && b[n - 1] == '\r') n--;               /* Windows line endings */
        hs_strs_add(l, hs_dup(b, n));
        if (!p) break;
        b = p + 1;
    }
    return l;
}
static void hs_write_file(hs_str path, hs_str text, const char *mode) {
    FILE *f = fopen(path, mode);
    if (!f) hs_raise(hs_fmt("cannot write %s", path));
    size_t n = strlen(text);
    if (fwrite(text, 1, n, f) != n) { fclose(f); hs_raise(hs_fmt("cannot write %s", path)); }
    fclose(f);
}
static void hs_write_text(hs_str path, hs_str text) { hs_write_file(path, text, "wb"); }
static void hs_append_text(hs_str path, hs_str text) { hs_write_file(path, text, "ab"); }
static bool hs_file_exists(hs_str path) {
    FILE *f = fopen(path, "rb");
    if (f) fclose(f);
    return f != NULL;
}
