"""Writes HasteSlate.style, Hasten's own FMX style: slate panels, a steel-blue accent, light text at 12 px.

Everything is drawn with vector shapes (rectangles, circles, paths) in the colours below: no bitmaps, nothing
taken from another style. It covers the controls Hasten uses; a control it does not cover (the font combo's
drop-down, the grid's header bar) falls back to the platform's own FMX style.

    python make_hasteslate.py            writes HasteSlate.style beside this script
"""
import os

# ---- the palette ----
WINDOW = 'xFF2B3640'      # form background
PANEL = 'xFF242D36'       # toolbar, status bar, tab strip
SURFACE = 'xFF3A4652'     # buttons
HOVER = 'xFF46535F'
PRESSED = 'xFF52606D'
INPUT = 'xFF1F262D'       # edit boxes, memos, trees
BORDER = 'xFF55626E'
ACCENT = 'xFF4F8CC9'      # focus and selection
SELECTION = 'x804F8CC9'   # selected text: the accent, half seen through
TEXT = 'xFFE3E7EB'
DIM = 'xFFA9B3BC'
THUMB = 'xFF5E6B77'
CLEAR = 'x00000000'
TEXT_SIZE = 12


def f(v):
    return f'{float(v):.6f}' + '0' * 12             # as Delphi writes it: 0.100000000000000000


class Obj:
    """An object in the style: its class, its properties (in order) and its children."""

    def __init__(self, cls, **props):
        self.cls, self.props, self.kids = cls, list(props.items()), []

    def add(self, *kids):
        self.kids += kids
        return self

    def write(self, ind):
        out = [' ' * ind + f'object {self.cls}']
        for k, v in self.props:
            k = k.replace('__', '.')
            if isinstance(v, bool):
                v = 'True' if v else 'False'
            elif isinstance(v, (int, float)):
                v = str(v) if k in ('FixedHeight', 'FixedWidth') else f(v)
            out.append(' ' * (ind + 2) + f'{k} = {v}')
        for kid in self.kids:
            out += kid.write(ind + 2)
        out.append(' ' * ind + 'end')
        return out


def q(s):
    """A Delphi string: ASCII in quotes, anything else as #code (the tick, the arrows)."""
    out, run = [], ''
    for ch in s:
        if 32 <= ord(ch) < 127:
            run += ch
        else:
            if run:
                out.append("'" + run.replace("'", "''") + "'")
                run = ''
            out.append('#' + str(ord(ch)))
    if run or not out:
        out.append("'" + run.replace("'", "''") + "'")
    return ''.join(out)


def glyph(char, color, size=TEXT_SIZE, **more):
    """A character drawn as a shape (a TPath's outline only loads from binary in a style)."""
    p = sized(16, 16, Align='Center', HitTest=False, Text=q(char))
    p.update(more)
    p['TextSettings__Font__Size'] = size
    p['TextSettings__FontColor'] = color
    return Obj('TText', **p)


def sized(w=None, h=None, **props):
    if w is not None:
        props['Size__Width'] = w
    if h is not None:
        props['Size__Height'] = h
    if w is not None or h is not None:
        props['Size__PlatformDefault'] = False
    return props


def rect(name=None, fill=SURFACE, stroke=None, radius=0, align='Contents', **more):
    p = {}
    if name:
        p['StyleName'] = q(name)
    if align:
        p['Align'] = align
    p['Fill__Color'] = fill
    p['HitTest'] = False
    if radius:
        p['XRadius'] = radius
        p['YRadius'] = radius
    if stroke:
        p['Stroke__Color'] = stroke
    else:
        p['Stroke__Kind'] = 'None'
    p.update(more)
    return Obj('TRectangle', **p)


def text(name='text', color=TEXT, halign=None, wrap=None, align='Client', **more):
    p = {'StyleName': q(name), 'Align': align, 'HitTest': False}
    p.update(more)
    p['TextSettings__Font__Size'] = TEXT_SIZE
    p['TextSettings__FontColor'] = color
    if halign:
        p['TextSettings__HorzAlign'] = halign
    if wrap is not None:
        p['TextSettings__WordWrap'] = wrap
    return Obj('TText', **p)


def colour_anim(prop, start, stop, trigger):
    return Obj('TColorAnimation', Duration=0.1, PropertyName=q(prop), StartValue=start, StopValue=stop,
               Trigger=q(trigger + '=true'), TriggerInverse=q(trigger + '=false'))


def fade(trigger, show=True):
    return Obj('TFloatAnimation', Duration=0.1, PropertyName=q('Opacity'), StartValue=0 if show else 1,
               StopValue=1 if show else 0, Trigger=q(trigger + '=true'), TriggerInverse=q(trigger + '=false'))


def text_parts():
    """What an edit, memo or spin box draws its text with."""
    return [Obj('TColorObject', StyleName=q('caretcolor'), Color=TEXT),
            Obj('TBrushObject', StyleName=q('foreground'), Brush__Color=TEXT),
            Obj('TBrushObject', StyleName=q('selection'), Brush__Color=SELECTION),
            Obj('TFontObject', StyleName=q('font'), Font__Size=TEXT_SIZE)]


def input_box(name='background'):
    """A sunken box with a border that lights up while it has the focus."""
    return rect(name, INPUT, BORDER, 2).add(colour_anim('Stroke.Color', BORDER, ACCENT, 'IsFocused'))


def scrollbars():
    return [Obj('TScrollBar', **sized(12, None, StyleName=q('vscrollbar'), Align='Right', SmallChange=0,
                                      Orientation='Vertical')),
            Obj('TScrollBar', **sized(None, 12, StyleName=q('hscrollbar'), Align='Bottom', SmallChange=0,
                                      Orientation='Horizontal'))]


def button_style(name, fill, stroke, radius):
    return rect(name, fill, stroke, radius, align=None).add(
        colour_anim('Fill.Color', fill, HOVER, 'IsMouseOver'),
        colour_anim('Fill.Color', HOVER, PRESSED, 'IsPressed'),
        text('text'))


def styles():
    s = []
    s.append(rect('backgroundstyle', WINDOW, align=None))
    s.append(Obj('TLayout', StyleName=q('labelstyle')).add(text('text', halign=None)))
    s.append(button_style('buttonstyle', SURFACE, BORDER, 3))
    s.append(button_style('speedbuttonstyle', CLEAR, None, 3))
    s.append(rect('toolbarstyle', PANEL, align=None))
    s.append(rect('statusbarstyle', PANEL, align=None))
    s.append(rect('splitterstyle', WINDOW, align=None))

    s.append(Obj('TLayout', StyleName=q('groupboxstyle')).add(
        rect('background', CLEAR, BORDER, 4, Margins__Top=9),
        text('text', color=DIM, align='None', **sized(300, 18, Position__X=10, Position__Y=0)),
    ))

    box = Obj('TLayout', **sized(22, None, Align='Left'))
    box.add(rect(None, INPUT, BORDER, 2, align='Center', **sized(16, 16)).add(
        glyph('\u2713', ACCENT, 13, Opacity=0).add(fade('IsChecked'))))
    s.append(Obj('TLayout', StyleName=q('checkboxstyle')).add(box, text('text', halign='Leading', Margins__Left=4)))

    dot = Obj('TLayout', **sized(22, None, Align='Left'))
    dot.add(Obj('TCircle', **sized(16, 16, Align='Center', HitTest=False, Fill__Color=INPUT, Stroke__Color=BORDER)).add(
        Obj('TCircle', **sized(8, 8, Align='Center', HitTest=False, Opacity=0, Fill__Color=ACCENT,
                               Stroke__Kind='None')).add(fade('IsChecked'))))
    s.append(Obj('TLayout', StyleName=q('radiobuttonstyle')).add(dot, text('text', halign='Leading', Margins__Left=4)))

    s.append(Obj('TLayout', StyleName=q('editstyle'), FixedHeight=24).add(
        input_box(),
        Obj('TLayout', StyleName=q('content'), Align='Client', Margins__Left=4, Margins__Right=4),
        Obj('TLayout', **sized(0, None, StyleName=q('buttons'), Align='Right')),
        *text_parts()))
    s.append(Obj('TLayout', StyleName=q('spinboxstyle'), FixedHeight=24).add(
        input_box(),
        Obj('TButton', **sized(22, None, StyleName=q('minusbutton'), Align='Left', Text=q('-'), CanFocus=False)),
        Obj('TButton', **sized(22, None, StyleName=q('plusbutton'), Align='Right', Text=q('+'), CanFocus=False)),
        Obj('TLayout', StyleName=q('content'), Align='Client', Margins__Left=4, Margins__Right=4),
        *text_parts()))
    s.append(Obj('TLayout', StyleName=q('textcellstyle')).add(
        Obj('TLayout', StyleName=q('content'), Align='Contents'), *text_parts()))

    s.append(Obj('TLayout', StyleName=q('memostyle')).add(
        input_box().add(Obj('TLayout', StyleName=q('content'), Align='Client', Margins__Left=2, Margins__Top=2),
                        *scrollbars()),
        *text_parts()))

    # scroll bars: a track and its thumb; no arrow buttons
    s.append(Obj('TLayout', StyleName=q('scrollbarstyle')).add(
        Obj('TTrack', StyleName=q('htrack'), Align='Client', Orientation='Horizontal', StyleLookup=q('scrollbarhtrackstyle')),
        Obj('TTrack', StyleName=q('vtrack'), Align='Client', Orientation='Vertical', StyleLookup=q('scrollbarvtrackstyle'))))
    for o, lookup in (('h', 'hthumbstyle'), ('v', 'vthumbstyle')):
        s.append(rect(f'scrollbar{o}trackstyle', INPUT, align=None).add(
            Obj('TThumb', StyleName=q('thumb'), StyleLookup=q(lookup))))
        s.append(rect(lookup, THUMB, None, 3, align=None, Margins__Left=2, Margins__Top=2, Margins__Right=2,
                      Margins__Bottom=2).add(colour_anim('Fill.Color', THUMB, BORDER, 'IsMouseOver')))

    # the Project Manager
    s.append(Obj('TLayout', StyleName=q('treeviewstyle')).add(
        Obj('TBrushObject', StyleName=q('AlternatingRowBackground'), Brush__Color=INPUT),
        rect('background', INPUT, None).add(
            Obj('TLayout', StyleName=q('content'), Align='Client').add(
                rect('selection', SELECTION, None, 2, align=None)),
            *scrollbars())))
    s.append(Obj('TLayout', StyleName=q('treeviewitemstyle')).add(
        Obj('TSpeedButton', **sized(19, None, StyleName=q('button'), Align='Left', StyleLookup=q('treeviewexpanderbuttonstyle'))),
        Obj('TLayout', Align='Contents', Margins__Left=20).add(
            Obj('TCheckBox', **sized(20, None, StyleName=q('check'), Align='Left', Visible=False)),
            text('text', halign='Leading', wrap=False))))
    s.append(Obj('TLayout', StyleName=q('treeviewexpanderbuttonstyle')).add(
        glyph('\u25B8', DIM).add(fade('IsExpanded', show=False)),
        glyph('\u25BE', DIM, Opacity=0).add(fade('IsExpanded'))))

    # editor tabs: the one on show joins the editor below it
    s.append(rect('tabcontrolstyle', PANEL, align=None).add(
        Obj('TBrushObject', StyleName=q('scrollbackground'), Brush__Color=PANEL)))
    s.append(Obj('TLayout', StyleName=q('tabitemstyle')).add(
        rect('top', PANEL, None).add(
            colour_anim('Fill.Color', PANEL, HOVER, 'IsMouseOver'),
            colour_anim('Fill.Color', PANEL, INPUT, 'IsSelected'),
            text('text', Margins__Left=12, Margins__Right=12, wrap=False)),
        Obj('TLayout', StyleName=q('bottom'), Align='Contents', Visible=False)))

    # the Options grid
    s.append(Obj('TLayout', StyleName=q('gridstyle')).add(
        Obj('TBrushObject', StyleName=q('AlternatingRowBackground'), Brush__Color='xFF252E37'),
        Obj('TBrushObject', StyleName=q('linefill'), Brush__Color=BORDER),
        rect('background', INPUT, BORDER).add(
            Obj('THeader', **sized(None, 24, StyleName=q('header'), Align='Top')),
            Obj('TLayout', StyleName=q('content'), Align='Client').add(
                rect('selection', SELECTION, None, align=None),
                rect('focus', CLEAR, ACCENT, align=None)),
            *scrollbars())))
    s.append(rect('headeritemstyle', SURFACE, BORDER, align=None).add(text('text', halign='Leading', Margins__Left=6, wrap=False)))
    s.append(rect('headerstyle', PANEL, align=None).add(Obj('TLayout', StyleName=q('content'), Align='Client')))

    # the tabs' scroll arrows, when there are more tabs than room
    for name, char in (('arrowlefttoolbutton', '\u25C2'), ('arrowrighttoolbutton', '\u25B8')):
        s.append(rect(name, CLEAR, None, 3, align=None).add(
            colour_anim('Fill.Color', CLEAR, HOVER, 'IsMouseOver'),
            glyph(char, DIM),
            text('text')))

    # menus: the menu bar (TMenuBar, drawn by FMX; the Mac keeps its own), its drop-downs and Hasten's
    # right-click menus
    s.append(rect('menubarstyle', PANEL, align=None).add(Obj('TLayout', StyleName=q('content'), Align='Client')))
    s.append(Obj('TLayout', StyleName=q('menubaritemstyle')).add(
        rect(None, HOVER, None, 2, Opacity=0).add(fade('IsMouseOver')),
        rect(None, PRESSED, None, 2, Opacity=0).add(fade('IsSelected')),
        text('text', halign='Center', wrap=False, align='Left', **sized(40, None, Margins__Left=8, Margins__Right=8))))
    s.append(Obj('TLayout', StyleName=q('menuviewstyle')).add(
        rect(None, PANEL, BORDER, align='Client'),
        Obj('TLayout', StyleName=q('content'), Align='Client', Margins__Left=2, Margins__Top=2,
            Margins__Right=2, Margins__Bottom=2)))
    check = Obj('TLayout', StyleName=q('checkmark'), Align='Contents', Opacity=0).add(
        glyph('\u2713', ACCENT), fade('IsChecked'))
    # proportions as RAD Studio's: an icon column, a wide gap before the shortcuts, room at the right
    s.append(Obj('TLayout', **sized(None, 28, StyleName=q('menuitemstyle'))).add(
        rect(None, SELECTION, None, 2, Opacity=0, Margins__Left=2, Margins__Right=2).add(fade('IsSelected')),   # by the keys, or its submenu open
        rect('background', SELECTION, None, 2, Opacity=0, Margins__Left=2, Margins__Right=2).add(fade('IsMouseOver')),   # under the mouse
        Obj('TLayout', **sized(34, None, StyleName=q('glyph'), Align='Left')).add(check),
        # a menu item is as wide as its parts: the text and shortcut at their own width, left and right
        text('text', halign='Leading', wrap=False, align='Left', **sized(50, None, Margins__Left=4)),
        text('shortcut', color=DIM, halign='Leading', wrap=False, align='Right',
             **sized(50, None, Margins__Left=56, Margins__Right=12)),
        Obj('TLayout', **sized(24, None, StyleName=q('submark'), Align='Right')).add(glyph('\u25B8', DIM))))
    s.append(Obj('TLayout', **sized(None, 9, StyleName=q('menuseparatorstyle'))).add(
        rect(None, BORDER, None, align='VertCenter', **sized(None, 1, Margins__Left=38, Margins__Right=6))))

    # the font box in Settings and its drop-down list
    s.append(Obj('TLayout', StyleName=q('comboeditstyle'), FixedHeight=24).add(
        input_box().add(Obj('TLayout', **sized(22, None, StyleName=q('arrow'), Align='Right')).add(glyph('\u25BE', DIM))),
        Obj('TLayout', StyleName=q('content'), Align='Client', Margins__Left=4, Margins__Right=24),
        *text_parts()))
    s.append(rect('combopopupstyle', PANEL, BORDER, align=None))
    s.append(Obj('TLayout', StyleName=q('listboxstyle')).add(
        Obj('TBrushObject', StyleName=q('AlternatingRowBackground'), Brush__Color=INPUT),
        rect('background', INPUT, BORDER).add(
            Obj('TLayout', StyleName=q('content'), Align='Client'),
            *scrollbars())))
    s.append(Obj('TLayout', StyleName=q('listboxitemstyle')).add(
        rect(None, HOVER, None, Opacity=0).add(fade('IsMouseOver')),
        rect(None, SELECTION, None, Opacity=0).add(fade('IsSelected')),
        text('text', halign='Leading', wrap=False, Margins__Left=6)))
    # the window's own frame: title bar, its buttons and the edges, drawn in the style (FMX on Windows). The
    # parts are in the order FMX's own styles give them: the mask, the bottom edge, the title bar, the client
    # area, the side edges. Every part takes the mouse (HitTest), the client area too: FMX tells Windows what
    # is under the mouse by the part it finds there, and with nothing found (a TLayout's HitTest is False
    # unless set) it answers title bar, so the form never gets a click.
    title_bar = rect('caption-container', PANEL, align='Top', **sized(None, 32, HitTest=True))
    title_bar.add(
        Obj('TLayout', StyleName=q('caption'), Align='Contents', HitTest=True),          # drags the window
        Obj('TLayout', **sized(36, None, StyleName=q('icon'), Align='Left', HitTest=True,
                               Margins__Left=8, Margins__Top=6, Margins__Bottom=6)),
        Obj('TLayout', StyleName=q('sysbtns'), Align='Client').add(
            Obj('TSpeedButton', **sized(46, None, StyleName=q('min'), Align='Right', StyleLookup=q('minbtnstyle'),
                                        Position__X=0)),
            Obj('TSpeedButton', **sized(46, None, StyleName=q('max'), Align='Right', StyleLookup=q('maxbtnstyle'),
                                        Position__X=46)),
            Obj('TSpeedButton', **sized(46, None, StyleName=q('close'), Align='Right', StyleLookup=q('closebtnstyle'),
                                        Position__X=92)),
            text('title', halign='Leading', wrap=False, Margins__Left=4)))
    s.append(Obj('TLayout', StyleName=q('windowborderstyle')).add(
        rect('mask', PANEL, None, 6, Visible=False),
        rect('bottom', BORDER, align='Bottom', **sized(None, 2, HitTest=True)),   # edges: 2 px, so they can be
        title_bar,                                                                  # caught to resize the window
        Obj('TLayout', StyleName=q('client'), Align='Client', HitTest=True),   # see above
        rect('left', BORDER, align='Left', **sized(2, None, HitTest=True)),
        rect('right', BORDER, align='Right', **sized(2, None, HitTest=True))))
    for name, char, hot in (('closebtnstyle', '\u2715', 'xFFC42B1C'), ('maxbtnstyle', '\u25A1', HOVER),
                            ('minbtnstyle', '\u2014', HOVER)):
        s.append(rect(name, CLEAR, align=None).add(
            colour_anim('Fill.Color', CLEAR, hot, 'IsMouseOver'),
            glyph(char, TEXT, 12),
            text('text')))
    return s


def main():
    root = Obj('TStyleContainer')
    root.add(Obj('TStyleDescription', StyleName=q('Description'), Author=q('Mark S Day'), AuthorEMail=q(''),
                 AuthorURL=q('https://github.com/GrooverMD/hasten-lang'), PlatformTarget=q(''),
                 MobilePlatform=False, Title=q('HasteSlate'), Version=q('1.0')))
    root.add(*styles())
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'HasteSlate.style')
    with open(path, 'w', newline='\r\n') as fh:
        fh.write('\n'.join(root.write(0)) + '\n')
    print(path)


if __name__ == '__main__':
    main()
