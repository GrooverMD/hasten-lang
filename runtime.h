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
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

typedef const char *hs_str;

static void *hs_alloc(size_t n) {
    void *p = calloc(1, n);
    if (!p) { fputs("out of memory\n", stderr); exit(2); }
    return p;
}

static hs_str hs_fmt(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *s = hs_alloc((size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(s, (size_t)n + 1, fmt, ap);
    va_end(ap);
    return s;
}

/* ---- errors: try/catch is a stack of jump buffers ---- */
static _Thread_local hs_str hs_error = "";
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
    char *r = hs_alloc(n * (size_t)(count > 0 ? count : 0) + 1);
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
    char *s = malloc((size_t)n + 1);            /* no need to zero what fread overwrites */
    if (!s) { fputs("out of memory\n", stderr); exit(2); }
    if (fread(s, 1, (size_t)n, f) != (size_t)n) hs_raise(hs_fmt("cannot read %s", path));
    s[n] = 0;
    fclose(f);
    return s;
}
/* Strings are immutable and never freed, so the length of the last string seen can be cached. */
static size_t hs_len(hs_str s) {
    static _Thread_local hs_str last;
    static _Thread_local size_t len;
    if (s != last) { last = s; len = strlen(s); }
    return len;
}
static long long hs_code(hs_str s, long long i) {
    if (i < 0 || (size_t)i >= hs_len(s)) hs_raise(hs_fmt("character %lld is outside the string", i));
    return (unsigned char)s[i];
}
static hs_str hs_sub(hs_str s, long long start, long long count) {
    size_t n = hs_len(s);
    if (start < 0 || count < 0 || (size_t)(start + count) > n) hs_raise("substring is outside the string");
    char *r = hs_alloc((size_t)count + 1);
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
            if (w->kind == 3) value = "true";
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
