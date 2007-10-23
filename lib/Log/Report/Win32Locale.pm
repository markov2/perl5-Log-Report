
package Log::Report::Win32Locale;
use base 'Exporter';

our @EXPORT = qw/codepage_to_iso iso_to_codepage
  iso_locale charset_encoding
  ms_codepage_id ms_install_codepage_id ms_locale/;
 
use Win32::TieRegistry;

my %codepage2iso;
while(<DATA>)
{  my ($codepage, $iso) = split;
   $codepage2iso{hex $codepage} = $iso;
}
my $iso2codepage = reverse $codepage2iso;

=chapter NAME
Log::Report::Win32Locale - unix/windows locales

=chapter SYNOPSYS
  # Only usable on Windows
  print codepage_to_iso(0x0413);   # nl-NL
  print iso_to_codepage('nl-NL');  # 1043
  printf "%x", iso_to_codepage('nl-NL');  # 413

  my $iso = iso_locale(ms_codepage_id());
  my $iso = iso_locale;  # same

  print charset_encoding;          # cp1252
  print ms_codepage_id;            # 1043
  print ms_install_codepage_id;    # 1043
  print ms_locale;                 # Dutch (Netherlands)

=chapter DESCRIPTION
Windows uses different locales to represent languages: codepages. Programs
which are written with Log::Report however, will contain ISO encoded
language names; this module translates between them.

The algorithms in this module are based on Win32::Locale and Win32::Codepage.

=chapter FUNCTIONS

=function codepage_to_iso CODEPAGE
Translate windows CODEPAGE into ISO code.  The CODEPAGE is numeric
or a hex string like '0x0304'.
=cut

sub codepage_to_iso($)
{   my $cp = shift;
    $codepage2iso{$cp =~ m/^0x/i ? hex($cp) : $cp};
}
 
=function iso_to_codepage ISO
Returns the numeric value of the codepage.  The ISO may look like
this: C<xx-YY>.  Then, first the C<xx-YY> is looked-up.  If that does
not exist, C<xx> is tried.
=cut

sub iso_to_codepage($)
{   my $iso = shift;
    return $iso2codepage{$iso}
        if $iso2codepage{$iso};

    my ($lang) = split $iso, /\-/;
    $iso2codepage{$lang};
}

=function iso_locale [CODEPAGE]
Returns the ISO string for the Microsoft codepage locale.  Might return
C<undef>/false.  By default, the actual codepage is used.
=cut

sub iso_locale(;$) { $codepage_to_iso(shift || ms_codepage_id || ms_locale) }

# the following functions are rewrites of Win32::Codepage version 1.00
# Copyright 2005 Clotho Advanced Media, Inc.  Under perl license.
# Win32 does not nicely export the functions.

my $nls = 'HKEY_LOCAL_MACHINE/SYSTEM/CurrentControlSet/Control/Nls';
my $del = {Delimiter => '/'};
my $codepages = Win32::TieRegistry->new("$nls/CodePage", $del);
my $languages = Win32::TieRegistry->new("$nls/Language", $del);

=fuction charset_encoding
Returns the encoding name (usable with module Encode) based on the current
codepage.  For example, C<cp1252> for iso-8859-1 (latin-1) or C<cp932> for
Shift-JIS Japanese.  Returns undef if the encoding cannot be identified.
=cut

sub charset_encoding
{   my $charset = $codepages->GetValue("ACP") || $codepages->GetValue("OEMCP");
    $charset && $charset =~ m/^[0-9a-fA-F]+$/ ? "cp".lc($charset) : undef;
}

=function ms_codepage_id
Returns the numeric language ID for the current codepage language.
For example, the numeric value for C<0x0409> for C<en-US>, and C<0x0411>
for C<ja>.  Returns false if the codepage cannot be identified.
=cut

sub ms_codepage_id
{   my $id = $languages->GetValue("Default");
    $id && $id =~ m/^[0-9a-fA-F]+$/ ? hex($id) : undef;
}

=function ms_install_codepage_id
Returns the numeric language ID for the installed codepage language.
This is like M<ms_codepage_id()>, but refers to the codepage that was
the default when Windows was first installed.
=cut

sub ms_install_codepage_id
{   my $id = $languages->GetValue("InstallLanguage");
    $id && $id =~ m/^[0-9a-fA-F]+$/ ? hex($id) : undef;
}
 
# the following functions are rewrites of Win32::Locale version 0.04
# Copyright (c) 2001,2003 Sean M. Burke,  Under perl license.
# The module seems unmaintained, and treating the 'region' in the ISO
# code as lower-case is a mistake.

my $i18n = Win32::TieRegistry->new
  ("HKEY_CURRENT_USER/Control Panel/International", $del);

=function ms_locale
Returns the locale setting from the control panel.
=cut

sub ms_locale
{   my $locale = $i18n->GetValue("Locale");
    $locale =~ m/^[0-9a-fA-F]+$/ ? hex($locale) : undef;
}

1;

# taken from http://www.microsoft.com/globaldev/nlsweb on 2007/10/22
# columns: codepage ISO language name
__DATA__
0x0036	af	Afrikaans
0x0436	af-ZA	Afrikaans (South Africa)
0x001C	sq	Albanian
0x041C	sq-AL	Albanian (Albania)
0x0484	gsw-FR	Alsatian (France)
0x045E	am-ET	Amharic (Ethiopia)
0x0001	ar	Arabic
0x1401	ar-DZ	Arabic (Algeria)
0x3C01	ar-BH	Arabic (Bahrain)
0x0C01	ar-EG	Arabic (Egypt)
0x0801	ar-IQ	Arabic (Iraq)
0x2C01	ar-JO	Arabic (Jordan)
0x3401	ar-KW	Arabic (Kuwait)
0x3001	ar-LB	Arabic (Lebanon)
0x1001	ar-LY	Arabic (Libya)
0x1801	ar-MA	Arabic (Morocco)
0x2001	ar-OM	Arabic (Oman)
0x4001	ar-QA	Arabic (Qatar)
0x0401	ar-SA	Arabic (Saudi Arabia)
0x2801	ar-SY	Arabic (Syria)
0x1C01	ar-TN	Arabic (Tunisia)
0x3801	ar-AE	Arabic (U.A.E.)
0x2401	ar-YE	Arabic (Yemen)
0x002B	hy	Armenian
0x042B	hy-AM	Armenian (Armenia)
0x044D	as-IN	Assamese (India)
0x002C	az	Azeri
0x082C	az-Cyrl-AZ	Azeri (Cyrillic, Azerbaijan)
0x042C	az-Latn-AZ	Azeri (Latin, Azerbaijan)
0x046D	ba-RU	Bashkir (Russia)
0x002D	eu	Basque
0x042D	eu-ES	Basque (Basque)
0x0023	be	Belarusian
0x0423	be-BY	Belarusian (Belarus)
0x0845	bn-BD	Bengali (Bangladesh)
0x0445	bn-IN	Bengali (India)
0x201A	bs-Cyrl-BA	Bosnian (Cyrillic, Bosnia and Herzegovina)
0x141A	bs-Latn-BA	Bosnian (Latin, Bosnia and Herzegovina)
0x047E	br-FR	Breton (France)
0x0002	bg	Bulgarian
0x0402	bg-BG	Bulgarian (Bulgaria)
0x0003	ca	Catalan
0x0403	ca-ES	Catalan (Catalan)
0x0C04	zh-HK	Chinese (Hong Kong S.A.R.)
0x1404	zh-MO	Chinese (Macao S.A.R.)
0x0804	zh-CN	Chinese (People's Republic of China)
0x0004	zh-Hans	Chinese (Simplified)
0x1004	zh-SG	Chinese (Singapore)
0x0404	zh-TW	Chinese (Taiwan)
0x7C04	zh-Hant	Chinese (Traditional)
0x0483	co-FR	Corsican (France)
0x001A	hr	Croatian
0x041A	hr-HR	Croatian (Croatia)
0x101A	hr-BA	Croatian (Latin, Bosnia and Herzegovina)
0x0005	cs	Czech
0x0405	cs-CZ	Czech (Czech Republic)
0x0006	da	Danish
0x0406	da-DK	Danish (Denmark)
0x048C	prs-AF	Dari (Afghanistan)
0x0065	div	Divehi
0x0465	div-MV	Divehi (Maldives)
0x0013	nl	Dutch
0x0813	nl-BE	Dutch (Belgium)
0x0413	nl-NL	Dutch (Netherlands)
0x0009	en	English
0x0C09	en-AU	English (Australia)
0x2809	en-BZ	English (Belize)
0x1009	en-CA	English (Canada)
0x2409	en-029	English (Caribbean)
0x4009	en-IN	English (India)
0x1809	en-IE	English (Ireland)
0x2009	en-JM	English (Jamaica)
0x4409	en-MY	English (Malaysia)
0x1409	en-NZ	English (New Zealand)
0x3409	en-PH	English (Republic of the Philippines)
0x4809	en-SG	English (Singapore)
0x1C09	en-ZA	English (South Africa)
0x2C09	en-TT	English (Trinidad and Tobago)
0x0809	en-GB	English (United Kingdom)
0x0409	en-US	English (United States)
0x3009	en-ZW	English (Zimbabwe)
0x0025	et	Estonian
0x0425	et-EE	Estonian (Estonia)
0x0038	fo	Faroese
0x0438	fo-FO	Faroese (Faroe Islands)
0x0464	fil-PH	Filipino (Philippines)
0x000B	fi	Finnish
0x040B	fi-FI	Finnish (Finland)
0x000C	fr	French
0x080C	fr-BE	French (Belgium)
0x0C0C	fr-CA	French (Canada)
0x040C	fr-FR	French (France)
0x140C	fr-LU	French (Luxembourg)
0x180C	fr-MC	French (Principality of Monaco)
0x100C	fr-CH	French (Switzerland)
0x0462	fy-NL	Frisian (Netherlands)
0x0056	gl	Galician
0x0456	gl-ES	Galician (Galician)
0x0037	ka	Georgian
0x0437	ka-GE	Georgian (Georgia)
0x0007	de	German
0x0C07	de-AT	German (Austria)
0x0407	de-DE	German (Germany)
0x1407	de-LI	German (Liechtenstein)
0x1007	de-LU	German (Luxembourg)
0x0807	de-CH	German (Switzerland)
0x0008	el	Greek
0x0408	el-GR	Greek (Greece)
0x046F	kl-GL	Greenlandic (Greenland)
0x0047	gu	Gujarati
0x0447	gu-IN	Gujarati (India)
0x0468	ha-Latn-NG	Hausa (Latin, Nigeria)
0x000D	he	Hebrew
0x040D	he-IL	Hebrew (Israel)
0x0039	hi	Hindi
0x0439	hi-IN	Hindi (India)
0x000E	hu	Hungarian
0x040E	hu-HU	Hungarian (Hungary)
0x000F	is	Icelandic
0x040F	is-IS	Icelandic (Iceland)
0x0470	ig-NG	Igbo (Nigeria)
0x0021	id	Indonesian
0x0421	id-ID	Indonesian (Indonesia)
0x085D	iu-Latn-CA	Inuktitut (Latin, Canada)
0x045D	iu-Cans-CA	Inuktitut (Syllabics, Canada)
0x083C	ga-IE	Irish (Ireland)
0x0434	xh-ZA	isiXhosa (South Africa)
0x0435	zu-ZA	isiZulu (South Africa)
0x0010	it	Italian
0x0410	it-IT	Italian (Italy)
0x0810	it-CH	Italian (Switzerland)
0x0011	ja	Japanese
0x0411	ja-JP	Japanese (Japan)
0x004B	kn	Kannada
0x044B	kn-IN	Kannada (India)
0x003F	kk	Kazakh
0x043F	kk-KZ	Kazakh (Kazakhstan)
0x0453	km-KH	Khmer (Cambodia)
0x0486	qut-GT	K'iche (Guatemala)
0x0487	rw-RW	Kinyarwanda (Rwanda)
0x0041	sw	Kiswahili
0x0441	sw-KE	Kiswahili (Kenya)
0x0057	kok	Konkani
0x0457	kok-IN	Konkani (India)
0x0012	ko	Korean
0x0412	ko-KR	Korean (Korea)
0x0040	ky	Kyrgyz
0x0440	ky-KG	Kyrgyz (Kyrgyzstan)
0x0454	lo-LA	Lao (Lao P.D.R.)
0x0026	lv	Latvian
0x0426	lv-LV	Latvian (Latvia)
0x0027	lt	Lithuanian
0x0427	lt-LT	Lithuanian (Lithuania)
0x082E	wee-DE	Lower Sorbian (Germany)
0x046E	lb-LU	Luxembourgish (Luxembourg)
0x002F	mk	Macedonian
0x042F	mk-MK	Macedonian (Former Yugoslav Republic of Macedonia)
0x003E	ms	Malay
0x083E	ms-BN	Malay (Brunei Darussalam)
0x043E	ms-MY	Malay (Malaysia)
0x044C	ml-IN	Malayalam (India)
0x043A	mt-MT	Maltese (Malta)
0x0481	mi-NZ	Maori (New Zealand)
0x047A	arn-CL	Mapudungun (Chile)
0x004E	mr	Marathi
0x044E	mr-IN	Marathi (India)
0x047C	moh-CA	Mohawk (Mohawk)
0x0050	mn	Mongolian
0x0450	mn-MN	Mongolian (Cyrillic, Mongolia)
0x0850	mn-Mong-CN	Mongolian (Traditional Mongolian, PRC)
0x0461	ne-NP	Nepali (Nepal)
0x0014	no	Norwegian
0x0414	nb-NO	Norwegian, Bokmål (Norway)
0x0814	nn-NO	Norwegian, Nynorsk (Norway)
0x0482	oc-FR	Occitan (France)
0x0448	or-IN	Oriya (India)
0x0463	ps-AF	Pashto (Afghanistan)
0x0029	fa	Persian
0x0429	fa-IR	Persian
0x0015	pl	Polish
0x0415	pl-PL	Polish (Poland)
0x0016	pt	Portuguese
0x0416	pt-BR	Portuguese (Brazil)
0x0816	pt-PT	Portuguese (Portugal)
0x0046	pa	Punjabi
0x0446	pa-IN	Punjabi (India)
0x046B	quz-BO	Quechua (Bolivia)
0x086B	quz-EC	Quechua (Ecuador)
0x0C6B	quz-PE	Quechua (Peru)
0x0018	ro	Romanian
0x0418	ro-RO	Romanian (Romania)
0x0417	rm-CH	Romansh (Switzerland)
0x0019	ru	Russian
0x0419	ru-RU	Russian (Russia)
0x243B	smn-FI	Sami, Inari (Finland)
0x103B	smj-NO	Sami, Lule (Norway)
0x143B	smj-SE	Sami, Lule (Sweden)
0x0C3B	se-FI	Sami, Northern (Finland)
0x043B	se-NO	Sami, Northern (Norway)
0x083B	se-SE	Sami, Northern (Sweden)
0x203B	sms-FI	Sami, Skolt (Finland)
0x183B	sma-NO	Sami, Southern (Norway)
0x1C3B	sma-SE	Sami, Southern (Sweden)
0x004F	sa	Sanskrit
0x044F	sa-IN	Sanskrit (India)
0x7C1A	sr	Serbian
0x1C1A	sr-Cyrl-BA	Serbian (Cyrillic, Bosnia and Herzegovina)
0x0C1A	sr-Cyrl-SP	Serbian (Cyrillic, Serbia)
0x181A	sr-Latn-BA	Serbian (Latin, Bosnia and Herzegovina)
0x081A	sr-Latn-SP	Serbian (Latin, Serbia)
0x046C	nso-ZA	Sesotho sa Leboa (South Africa)
0x0432	tn-ZA	Setswana (South Africa)
0x045B	si-LK	Sinhala (Sri Lanka)
0x001B	sk	Slovak
0x041B	sk-SK	Slovak (Slovakia)
0x0024	sl	Slovenian
0x0424	sl-SI	Slovenian (Slovenia)
0x000A	es	Spanish
0x2C0A	es-AR	Spanish (Argentina)
0x400A	es-BO	Spanish (Bolivia)
0x340A	es-CL	Spanish (Chile)
0x240A	es-CO	Spanish (Colombia)
0x140A	es-CR	Spanish (Costa Rica)
0x1C0A	es-DO	Spanish (Dominican Republic)
0x300A	es-EC	Spanish (Ecuador)
0x440A	es-SV	Spanish (El Salvador)
0x100A	es-GT	Spanish (Guatemala)
0x480A	es-HN	Spanish (Honduras)
0x080A	es-MX	Spanish (Mexico)
0x4C0A	es-NI	Spanish (Nicaragua)
0x180A	es-PA	Spanish (Panama)
0x3C0A	es-PY	Spanish (Paraguay)
0x280A	es-PE	Spanish (Peru)
0x500A	es-PR	Spanish (Puerto Rico)
0x0C0A	es-ES	Spanish (Spain)
0x540A	es-US	Spanish (United States)
0x380A	es-UY	Spanish (Uruguay)
0x200A	es-VE	Spanish (Venezuela)
0x001D	sv	Swedish
0x081D	sv-FI	Swedish (Finland)
0x041D	sv-SE	Swedish (Sweden)
0x005A	syr	Syriac
0x045A	syr-SY	Syriac (Syria)
0x0428	tg-Cyrl-TJ	Tajik (Cyrillic, Tajikistan)
0x085F	tmz-Latn-DZ	Tamazight (Latin, Algeria)
0x0049	ta	Tamil
0x0449	ta-IN	Tamil (India)
0x0044	tt	Tatar
0x0444	tt-RU	Tatar (Russia)
0x004A	te	Telugu
0x044A	te-IN	Telugu (India)
0x001E	th	Thai
0x041E	th-TH	Thai (Thailand)
0x0451	bo-CN	Tibetan (PRC)
0x001F	tr	Turkish
0x041F	tr-TR	Turkish (Turkey)
0x0442	tk-TM	Turkmen (Turkmenistan)
0x0480	ug-CN	Uighur (PRC)
0x0022	uk	Ukrainian
0x0422	uk-UA	Ukrainian (Ukraine)
0x042E	wen-DE	Upper Sorbian (Germany)
0x0020	ur	Urdu
0x0420	ur-PK	Urdu (Islamic Republic of Pakistan)
0x0043	uz	Uzbek
0x0843	uz-Cyrl-UZ	Uzbek (Cyrillic, Uzbekistan)
0x0443	uz-Latn-UZ	Uzbek (Latin, Uzbekistan)
0x002A	vi	Vietnamese
0x042A	vi-VN	Vietnamese (Vietnam)
0x0452	cy-GB	Welsh (United Kingdom)
0x0488	wo-SN	Wolof (Senegal)
0x0485	sah-RU	Yakut (Russia)
0x0478	ii-CN	Yi (PRC)
0x046A	yo-NG	Yoruba (Nigeria)
