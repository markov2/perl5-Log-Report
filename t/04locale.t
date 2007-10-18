#!/usr/bin/perl
# test locale

use Test::More;
use POSIX;

my $alt_locale;
BEGIN  {
   eval "POSIX->import( qw/setlocale :locale_h/ )";

   # locale disabled?
   defined setlocale(LC_ALL, 'POSIX')
      or plan skip_all => "no translation support in Perl or OS";

 LOCALE:
   foreach my $l (qw/nl_NL de_DE pt_PT tr_TR/)  # only non-english!
   {   foreach my $c (qw/utf-8 iso-8859-1/)
       {   $alt_locale = "$l.$c";
           last LOCALE
               if defined setlocale(LC_ALL, "$alt_locale");
       }
       undef $alt_locale;
   }

   defined $alt_locale
       or plan skip_all => "cannot find alternative language for tests";

   plan tests => 11;
}

ok(1, "alt locale: $alt_locale");

ok(defined setlocale(LC_ALL, 'POSIX'), 'set POSIX');

my $try = setlocale LC_ALL;
ok(defined $try, 'explicit POSIX found');
ok($try eq 'POSIX' || $try eq 'C');  # GNU changes colour

$! = 2;
my $err_posix = "$!";
ok(defined $err_posix, $err_posix);  # english

$try = setlocale LC_ALL, $alt_locale;
ok(defined $try, 'defined return for alternative locale');
is($try, $alt_locale);

is(setlocale(LC_ALL), $alt_locale, "set successful?");
$! = 2;
my $err_alt = "$!";
ok(defined $err_alt, $err_alt);
isnt($err_posix, $err_alt, "locale = $alt_locale");

setlocale(LC_ALL, 'POSIX');
$! = 2;
my $err_posix2 = "$!";
is($err_posix, $err_posix2, $err_posix2);
