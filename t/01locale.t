#!/usr/bin/perl
# test locale

use Test::More;
use POSIX;

my $default;
BEGIN  {
   eval "POSIX->import( qw/setlocale :locale_h/ )";
   $@ and plan skip_all => "no translation support in Perl or OS";

   $default = setlocale(LC_MESSAGES);
   plan tests => 10;
}

ok(1, "default locale: $default");

my $try = setlocale LC_MESSAGES, 'en_GB';
ok(defined $try, 'defined return');
is($try, 'en_GB');

$! = 2;
my $err_en = "$!";
ok(defined $err_en, $err_en);  # platform dependent

$try = setlocale LC_MESSAGES, 'nl_NL';
ok(defined $try, 'defined return');
is($try, 'nl_NL');

is(setlocale(LC_MESSAGES), 'nl_NL');
$! = 2;
my $err_nl = "$!";
ok(defined $err_nl, $err_nl);
isnt($err_en, $err_nl);

setlocale(LC_MESSAGES, 'en_US');
$! = 2;
my $err_en2 = "$!";
is($err_en, $err_en2, $err_en2);
