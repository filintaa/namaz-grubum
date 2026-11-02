"""Create a redacted App Review evidence attachment from ASC and local records."""
from pathlib import Path
from xml.sax.saxutils import escape
import json
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER
import asc_screenshots as asc

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/pdf'
OUT.mkdir(parents=True, exist_ok=True)
testers = asc.api('GET', f'/betaTesters?filter[apps]={asc.APP_ID}&limit=200')['data']
feedback = asc.api('GET', f'/apps/{asc.APP_ID}/betaFeedbackScreenshotSubmissions?limit=200&include=build')
builds = {x['id']: x['attributes']['version'] for x in feedback.get('included', []) if x['type'] == 'builds'}
installed = [x for x in testers if x['attributes']['state'] == 'INSTALLED']
versions = asc.api('GET', f'/apps/{asc.APP_ID}/appStoreVersions')['data']
version = versions[0]
linked = asc.api('GET', f'/appStoreVersions/{version["id"]}/build')['data']
redacted = {
    'verified_date': '2026-10-21', 'app_id': asc.APP_ID,
    'app_store_state': version['attributes']['appStoreState'],
    'linked_build': linked['attributes']['version'],
    'installed_tester_accounts': len(installed),
    'invited_only_accounts': sum(x['attributes']['state'] == 'INVITED' for x in testers),
    'feedback_records': len(feedback['data']),
    'devices': [d for x in installed for d in x['attributes'].get('appDevices', [])],
    'feedback': [{'date': x['attributes']['createdDate'], 'build': builds.get(x.get('relationships', {}).get('build', {}).get('data', {}).get('id')), 'comment': x['attributes']['comment']} for x in feedback['data']],
}
(OUT / 'TestFlight-records-redacted.json').write_text(json.dumps(redacted, ensure_ascii=False, indent=2))
styles = getSampleStyleSheet()
styles['BodyText'].fontSize = 10
styles['BodyText'].leading = 13
styles['Heading2'].spaceBefore = 8
styles['Heading2'].spaceAfter = 6
styles.add(ParagraphStyle(name='SmallNote', fontSize=9, leading=12, textColor=colors.HexColor('#5d6570')))
styles.add(ParagraphStyle(name='ScreenCaption', fontSize=10, leading=14, alignment=TA_CENTER, spaceAfter=12))
story = []
def p(text, style='BodyText'):
    story.append(Paragraph(text, styles[style])); story.append(Spacer(1, 6))
def heading(text): p(text, 'Heading2')
p('Namaz Grubum | App Review evidence', 'Title')
p('Guidelines 4.3 and 4.2.6 - supporting information<br/>Verified 21 October 2026', 'SmallNote')
heading('1. Product boundary')
p('<b>Kolay Namaz:</b> gradual individual support for starting or returning to prayer, including beginning with one daily prayer, learning and mentor support.')
p('<b>Namaz Grubum:</b> friends who already pray coordinate waking and participation using groups, membership approval, shared states, member reminders and optional group photo submissions.')
p('The products overlap in prayer times and reminders. Their primary tasks differ: individual beginner guidance versus a multi-user group service. The developer states that their application code and interface designs were developed separately.')
heading('2. Records verified through App Store Connect')
rows = [['Record', 'Verified result'], ['Installed tester accounts', str(len(installed)) + ' (developer + one additional tester)'], ['Invitation-only accounts', str(redacted['invited_only_accounts']) + ' (excluded from participants)'], ['Physical device models', 'iPhone SE (2nd generation); iPhone 14 Pro Max'], ['Latest device build records', 'Both show 1.0.0 (10)'], ['Screenshot feedback', str(len(feedback['data'])) + ' records: 14 developer, 3 additional tester'], ['Feedback date range', '10 September - 2 October 2026'], ['Rejected version / linked build', '1.0 / build ' + str(redacted['linked_build'])]]
t = Table(rows, colWidths=[180, 323], hAlign='LEFT')
t.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e9eef3')), ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'), ('FONTSIZE', (0, 0), (-1, -1), 9), ('LEADING', (0, 0), (-1, -1), 12), ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BOTTOMPADDING', (0, 0), (-1, -1), 9), ('TOPPADDING', (0, 0), (-1, -1), 9), ('LINEBELOW', (0, 0), (-1, -1), .4, colors.HexColor('#d7dee5'))]))
t.setStyle(TableStyle([('BOTTOMPADDING',(0,0),(-1,-1),6),('TOPPADDING',(0,0),(-1,-1),6)]))
story.append(t); story.append(Spacer(1, 8))
p('These are account/device records, not session-duration measurements or a large external beta study. Names, email addresses, credentials and signed image URLs are omitted.', 'SmallNote')
heading('3. Feedback applied during development')
for title, body in [
    ('Onboarding appeared repeatedly', 'Persisted completion before permission-related work.'),
    ('Title/role collision on a narrow display', 'Separated the group title and role badge.'),
    ('Join action remained in a loading state', 'Added timeout handling and explicit outcome states.'),
    ('Owner could report their own group', 'Hid that menu action for owners and administrators. Report came from the additional tester.'),
    ('Wake-up confirmation was too brief', 'Added clear confirmation lasting three seconds. Report came from the additional tester.')]:
    p('<b>' + title + ':</b> ' + body)
p('Build scope: the rejected submission is linked to build 8. Further improvements exist in TestFlight builds 9-10 and are not claimed as changes already reviewed in build 8. Local build-10 validation records show clean static analysis and 31 passing tests.', 'SmallNote')
story.append(PageBreak())
heading('4. Group workflow screens')
p('The following simulator captures use sample group/member data. They illustrate the interface, not live customer usage. They are not certified captures of the rejected build 8.', 'SmallNote')
shots = [('02-grup-detayi.png', 'Group detail - shared participation and group actions'), ('03-grup-uyeleri.png', 'Members - member participation states'), ('04-gruplarim.png', 'My groups - participating groups'), ('06-katilim-istekleri.png', 'Admission requests - owner/administrator workflow')]
for start in [0, 2]:
    if start: story.append(PageBreak())
    cells=[]
    for name, caption in shots[start:start+2]:
        path=ROOT/'artifacts/guncel-uygulama-ekranlari'/name
        im=Image(str(path), width=220, height=220*2622/1206)
        cells.append([Paragraph(caption, styles['ScreenCaption']), im])
    layout=Table([cells], colWidths=[251,251], hAlign='CENTER')
    layout.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12)]))
    story.append(layout)
    p('Review navigation: "Gruplarim" opens participating groups; a group opens its participation and member screens. "Katilim Istekleri" manages admission. Prayer action availability depends on the prayer period.', 'SmallNote')
def footer(canvas, doc):
    canvas.setFont('Helvetica',8); canvas.setFillColor(colors.HexColor('#6b7280'))
    canvas.drawString(46,25,'Namaz Grubum | Supporting information | 21 October 2026')
    canvas.drawRightString(550,25,str(doc.page))
doc=SimpleDocTemplate(str(OUT/'Namaz-Grubum-App-Review-Evidence.pdf'), pagesize=(595.28,841.89), leftMargin=46,rightMargin=46,topMargin=38,bottomMargin=42)
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(OUT/'Namaz-Grubum-App-Review-Evidence.pdf')
