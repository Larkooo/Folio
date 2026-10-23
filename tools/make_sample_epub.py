#!/usr/bin/env python3
"""Builds Folio/Resources/harbour-light.epub, the original sample book bundled with the app.

Run from the repository root:  python3 tools/make_sample_epub.py
"""
import html
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Folio" / "Resources" / "harbour-light.epub"

TITLE = "The Harbour Light"
AUTHOR = "Folio Sample Edition"

# Chapters are written in a tiny markup: blank lines separate paragraphs, *x* is italic,
# lines starting with "> " are a quotation, and a line containing only "* * *" is a scene break.
CHAPTERS = [
    ("One", "The Keeper’s House", """
Ines Aldana arrived on Skerrow in the last week of October, on the mail boat that came twice a week when the weather allowed it. She brought a canvas bag, a box of books, and a letter from the harbour board that set out her duties in four short paragraphs. The light at the end of the north pier was to be lit at dusk and put out at dawn. The lens was to be cleaned each morning. The log was to be kept in ink.

The boatman, a broad and quiet man named Corran, carried her box up the slipway without being asked and set it down outside a small white house with a slate roof. The house stood at the root of the pier, so close to the water that the windows on the seaward side were furred with salt.

“The last keeper left the stove going,” he said. “It wants coaxing in the mornings.”

She thanked him, and he nodded and went back down to his boat. For a while she stood alone with her hand on the latch, listening to the halyards ringing against the masts in the harbour.

Inside, the house was clean and very plain. There was a table, two chairs, a bed under the eaves, and a shelf of tide tables going back twenty years. On the table lay the log, a heavy book bound in green cloth. Its last entry was written in a careful upright hand: *Wind south-west, moderate. Visibility good. Lit 16.52. All well.*

Ines had spent thirty-one years drawing coastlines for other people. She had drawn this one, in fact, though she had never seen it. She remembered the survey sheets, the soundings in their tiny figures, and the way the island had looked on paper: a ragged comma at the edge of the chart, with the pier a straight line pointing north. On paper there had been no smell of seaweed and coal smoke, no gulls arguing on the roof, and no light changing on the water every minute of the afternoon.

She unpacked her books first, as she always did, and put them on the shelf beside the tide tables. Then she lit the stove, which did want coaxing, and made tea, and sat at the table with the log open in front of her until the sky over the harbour began to thin and turn the colour of pewter.

At half past four she put on her coat and walked out along the pier. The stones were wet and uneven, and the wind, which had seemed mild from the house, leaned on her steadily from the west. At the end of the pier the light stood on its square tower, no taller than a chapel, painted white with a red door. She climbed the iron stairs inside, counting them without meaning to. There were forty-two.

The lamp room was smaller than she had pictured and brighter, even in the dusk. The lens sat in its brass frame like a great glass beehive, every ring of it holding a piece of the evening. She wiped it once with the cloth that hung on its hook, though it did not need wiping, and then she lit the lamp the way the letter described, and stood back.

Nothing dramatic happened. A steady white light filled the lens and went out across the water, and the harbour, which had been sinking into the dark, took on edges again: the pale line of the breakwater, the boats on their moorings, the first windows lit along the shore.

She went down the forty-two stairs and back along the pier to the house, and she wrote her first entry under the careful upright hand of the keeper before her.

*Wind west, light. Visibility good. Lit 16.49. All well.*
"""),
    ("Two", "Weather", """
By the end of her first fortnight Ines had learned that the weather on Skerrow was less a condition than a conversation. Everyone took part in it. At the shop, Mrs. Feeney weighed out tea and gave her opinion of the coming week before she gave the change. The children who waited for the school bus at the top of the slipway forecast rain with great confidence and were usually right. Even Corran, who said little about anything, would look at the sky over the mainland and say “Thursday” in a tone that settled the matter.

She began to keep her own notes alongside the log, in a smaller notebook with squared paper. In it she recorded the things the log had no column for: the colour of the water at the harbour mouth, the height of the swell against the third ladder on the pier, the hour the oystercatchers came down to the shingle. She found she was drawing again, small careful sketches in the margins, the breakwater from the lamp room, the curve of the bay at low tide.

The boats had names, and she learned them the way she had once learned the names of headlands. The *Mairead* was blue and went out early. The *Second Chance* had been painted so many times that its timbers looked upholstered. The *Kittiwake* belonged to Corran, and it was the only one that always came in last, low in the water, with gulls trailing behind it like a loose thread.

* * *

On a still morning in November she cleaned the lens and then, instead of going down at once, sat on the floor of the lamp room with her back against the warm brass and looked out. The sea was the flat grey of a slate roof after rain. A seal lay on the rocks below the breakwater, turning its head now and then to consider the sky. Far out, the mail boat was a white mark on the water, crawling toward the island with the week’s letters.

She thought about how many hours she had spent looking at maps of places like this and how few she had spent in them. It had never troubled her before. The maps had been exact, and she had been proud of them. But a map, she thought now, is a record of where things are, and it says nothing about how long they take. It did not show that the walk from the house to the light was eleven minutes in a westerly and seven in an easterly. It did not show the forty-two stairs.

When the mail boat came in she went down to meet it, because everyone did. There was nothing for her, as she had expected, and she walked back along the shore with Mrs. Feeney, who was carrying a parcel of knitting wool and an opinion about Thursday.
"""),
    ("Three", "The Letter", """
The letter came in December, in a blue envelope addressed in a hand she had not seen for nine years. She knew it before she had read the name. Her brother had always written his capital letters too large, as if each word were the beginning of a sentence.

She did not open it at once. She put it on the shelf beside the tide tables and went about the day as if it were not there: the lens, the log, the walk to the shop. In the evening she lit the light and stood in the lamp room longer than she needed to, watching the beam go out over the water and come back, out and back, as steady as breathing.

When she did open it, at the table, with the stove ticking as it cooled, it was shorter than she had feared.

> Ines. I heard from Marta that you had left the office and gone north to keep a light, which is the most like you of anything I have heard in years. I have thought many times about what I said at our father’s house, and I have thought about it more since I stopped being certain I was right. I am not writing to ask for anything. I wanted you to know that I think of you, and that the door here is open if you ever want to walk through it. Tomás.

She read it twice and then sat for a long time with her hands flat on the table on either side of it.

Their quarrel had been about the house, at first, and then about everything the house had stood for, and in the end about nothing either of them could have named. She remembered the room they had shouted in more clearly than the words. She remembered the clock on the mantel and the green curtains, and the way her brother had stood by the window with his back to her, as if the argument were happening somewhere outside.

For nine years she had kept that room exactly as it was, the way she might have kept a survey sheet that she had once drawn badly and could not bring herself to redraw. It had been easier to keep it than to look at it.

She did not answer that night. She put the letter back in its envelope and the envelope back on the shelf. But before she went to bed she opened the log and, after the usual line about the wind and the visibility, she wrote something she had never written in a log before. She wrote: *Letter from T.* Then she looked at it for a while, and left it there.
"""),
    ("Four", "Night Watch", """
The storm came three days before Christmas, and it came the way the island had said it would. The wind backed to the south in the morning, and by noon the mail boat had turned around halfway across and gone home. By three the spray was coming over the end of the pier in long white sheets, and the boats in the harbour were pulling at their moorings like dogs on leads.

Ines lit the light early. The letter from the harbour board said nothing about storms, but the old log did. In the hand of the careful keeper, and in other hands before that, she found the same line repeated across the years: *Kept watch.* So she brought a flask and a blanket up the forty-two stairs, and she kept watch.

The lamp room shook. Not much, but enough that she could feel it through the soles of her boots, a slow trembling every time a wave struck the base of the tower. The windows streamed. Beyond them there was nothing to see but the beam itself, reaching out into the rain and losing itself there, and the dim shape of the breakwater flickering white where the sea broke over it.

At seven Mrs. Feeney telephoned the house, and when there was no answer she telephoned the light, which had a black handset on the wall that Ines had never heard ring. The *Kittiwake* had not come in. Corran had gone out in the morning to lift his pots before the weather turned, and he was not back.

“He’ll come in on your light,” Mrs. Feeney said. “He always does.”

So Ines watched the light. She did nothing to it, because there was nothing to do; it turned and shone exactly as it had every evening since October. But she found that she could not look away from it, as if her attention were part of what kept it burning. She thought of all the keepers whose names were in the log, and of the nights they had spent in this small bright room while the island waited below.

At a quarter past nine she saw it: a smaller light, low on the water to the north-east, appearing and vanishing between the waves. It was moving very slowly. It vanished for so long that she stopped breathing, and then it appeared again, closer, and she understood that it was coming straight down the line of the beam, as if the beam were a rope and the boat were pulling itself in along it.

It took the *Kittiwake* forty minutes to come the last mile. When it passed the end of the pier, close enough that she could see the shape of a man at the wheel, she put her hand flat on the cold glass of the window, and then she sat down on the floor because her legs would not hold her any longer.

In the log, when she came down near midnight, she wrote: *Wind south, storm force. Visibility poor. Kittiwake in 21.58. Kept watch.* And then, after a moment, the words the other keepers had written on their hardest nights, because they were true. *All well.*
"""),
    ("Five", "Morning", """
In the morning the storm had gone as completely as if it had never been. The sky was washed and very high, and the harbour lay still under it, strewn with weed and broken crates and the white bodies of gulls riding the swell. Ines put out the light at dawn and stood for a while at the top of the tower, looking at the island as she had first seen it on paper: the ragged comma, the straight line of the pier.

It looked different now. Not because anything on it had changed, but because she knew how long things took. She knew it was eleven minutes to the house in a westerly. She knew where the seal liked to lie, and which boat went out first, and that Thursday, when the island said Thursday, meant Thursday.

Corran was at the slipway when she came down, mending a cleat on the *Kittiwake* with the slow attention of a man who has decided not to talk about something. He looked up as she passed and nodded, and she nodded back, and that was all either of them said. It was, she thought, a great deal.

* * *

At the table, with the stove going, she took the blue envelope down from the shelf and set it beside a clean sheet of paper. She wrote the date, and then her brother’s name, and then nothing for a long while.

In the end it was not hard. She wrote that she had received his letter. She wrote that she kept a light now, on an island at the edge of the chart, and that it was the most like her of anything she had done in years. She wrote that she had kept the room in their father’s house exactly as it was for nine years, and that she was tired of keeping it. She wrote that in the spring, when the mail boat ran more often, there was a spare chair at her table and a view of the harbour from the window.

She read it through once and did not change a word. Then she put on her coat and walked to the shop, where Mrs. Feeney sold her a stamp and told her the next three days would be fine.

That evening she climbed the forty-two stairs at dusk, wiped the lens, which did not need wiping, and lit the lamp. The beam went out over the quiet water and came back, out and back, steady as breathing. Below her the windows of the island came on one by one along the shore.

*Wind north-west, light. Visibility excellent. Lit 16.41. Letter to T. All well.*
"""),
]


def inline(text: str) -> str:
    escaped = html.escape(text, quote=False)
    return re.sub(r"\*(.+?)\*", r"<em>\1</em>", escaped)


def chapter_body(source: str) -> str:
    blocks = []
    for block in source.strip().split("\n\n"):
        block = block.strip()
        if block == "* * *":
            blocks.append("<hr/>")
        elif block.startswith("> "):
            blocks.append(f"<blockquote><p>{inline(block[2:])}</p></blockquote>")
        else:
            blocks.append(f"<p>{inline(block)}</p>")
    return "\n    ".join(blocks)


def xhtml(title: str, body: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en" lang="en">
  <head>
    <title>{html.escape(title)}</title>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    {body}
  </body>
</html>
"""


def main() -> None:
    files = {}
    files["OEBPS/title.xhtml"] = xhtml(TITLE, f"""<section epub:type="titlepage">
      <h1>{TITLE}</h1>
      <p>A short original story included with Folio so there is something to read on first launch.</p>
    </section>""")

    manifest = ['<item id="title" href="title.xhtml" media-type="application/xhtml+xml"/>']
    spine = ['<itemref idref="title"/>']
    nav = []
    for index, (number, name, text) in enumerate(CHAPTERS, start=1):
        filename = f"chapter-{index}.xhtml"
        heading = f"<h2>Chapter {number}<br/>{html.escape(name)}</h2>"
        files[f"OEBPS/{filename}"] = xhtml(name, f'<section epub:type="chapter">\n    {heading}\n    {chapter_body(text)}\n    </section>')
        manifest.append(f'<item id="c{index}" href="{filename}" media-type="application/xhtml+xml"/>')
        spine.append(f'<itemref idref="c{index}"/>')
        nav.append(f'<li><a href="{filename}">{html.escape(name)}</a></li>')

    files["OEBPS/nav.xhtml"] = xhtml("Contents", f"""<nav epub:type="toc" id="toc">
      <h1>Contents</h1>
      <ol>
        {"".join(nav)}
      </ol>
    </nav>""")
    files["OEBPS/style.css"] = "body { font-family: serif; }\nh1, h2 { text-align: center; }\n"
    files["OEBPS/content.opf"] = f"""<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">urn:folio:sample:harbour-light</dc:identifier>
    <dc:title>{TITLE}</dc:title>
    <dc:creator>{AUTHOR}</dc:creator>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-10-23T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="css" href="style.css" media-type="text/css"/>
    {chr(10).join("    " + m for m in manifest).strip()}
  </manifest>
  <spine>
    {chr(10).join("    " + s for s in spine).strip()}
  </spine>
</package>
"""
    files["META-INF/container.xml"] = """<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
"""

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUT, "w") as archive:
        archive.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        for path, content in files.items():
            archive.writestr(path, content, compress_type=zipfile.ZIP_DEFLATED)
    words = sum(len(text.split()) for _, _, text in CHAPTERS)
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes, {words} words)")


if __name__ == "__main__":
    main()
