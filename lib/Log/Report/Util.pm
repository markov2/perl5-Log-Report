
use warnings;
use strict;

package Log::Report::Util;
use base 'Exporter';

our @EXPORT = qw/@reasons %reason_code parse_locale expand_reasons
  escape_chars unescape_chars/;

use Log::Report 'log-report', syntax => 'SHORT';

# ordered!
our @reasons = N__w('TRACE ASSERT INFO NOTICE WARNING
    MISTAKE ERROR FAULT ALERT FAILURE PANIC');
our %reason_code; { my $i=1; %reason_code = map { ($_ => $i++) } @reasons }

my @user    = qw/MISTAKE ERROR/;
my @program = qw/TRACE ASSERT INFO NOTICE WARNING PANIC/;
my @system  = qw/FAULT ALERT FAILURE/;

=chapter NAME
Log::Report::Util - helpful routines to Log::Report

=chapter SYNOPSYS
 my ($language, $territory, $charset, $modifier)
    = parse_locale 'nl_BE.utf-8@home';

 my @take = expand_reasons 'INFO-ERROR,PANIC';

=chapter DESCRIPTION

=chapter FUNCTIONS

=function parse_locale STRING
Returns a LIST of four elements when successful, and an empty
LIST when the locale is not correct.  The LIST order is country,
territory, character-set (codeset), and modifier.
=cut

sub parse_locale($)
{  $_[0] =~
     m/^ ([a-z]{2})              # ISO 631
         (?: \_ ([a-zA-Z\d]+)    # ISO 3166
             (?: \. ([\w-]+) )?  # codeset
         )?
         (?: \@ (\S+) )?         # modifier
           $
      /x;
}

=function expand_reasons REASONS
Returns a sub-set of all existing message reason labels, based on the
content REASONS string. The following rules apply:
 REASONS = BLOCK [ ',' BLOCKS]
 BLOCK   = '-' TO | FROM '-' TO | ONE | SOURCE
 FROM,TO,ONE = 'TRACE' | 'ASSERT' | ,,, | 'PANIC'
 SOURCE  = 'USER' | 'PROGRAM' | 'SYSTEM' | 'ALL'

The SOURCE specification group all reasons which are usually related to
the problem: report about problems caused by the user, reported by
the program, or with system interaction.

=examples of expended REASONS
 WARNING-FAULT # == WARNING,MISTAKE,ERROR,FAULT
 -INFO         # == TRACE-INFO
 ALERT-        # == ALERT,FAILURE,PANIC
 USER          # == MISTAKE,ERROR
 ALL           # == TRACE-PANIC
=cut

sub expand_reasons($)
{   my $reasons = shift;
    my %r;
    foreach my $r (split m/\,/, $reasons)
    {   if($r =~ m/^([a-z]*)\-([a-z]*)/i )
        {   my $begin = $reason_code{$1 || 'TRACE'};
            my $end   = $reason_code{$2 || 'PANIC'};
            $begin && $end
                or error __x"unknown reason {which} in '{reasons}'"
                       , which => ($begin ? $2 : $1), reasons => $reasons;

            error __x"reason '{begin}' more serious than '{end}' in '{reasons}"
                , begin => $1, end => $2, reasons => $reasons
                if $begin >= $end;

            $r{$_}++ for $begin..$end;
        }
        elsif($reason_code{$r}) { $r{$reason_code{$r}}++ }
        elsif($r eq 'USER')     { $r{$reason_code{$_}}++ for @user    }
        elsif($r eq 'PROGRAM')  { $r{$reason_code{$_}}++ for @program }
        elsif($r eq 'SYSTEM')   { $r{$reason_code{$_}}++ for @system  }
        elsif($r eq 'ALL')      { $r{$reason_code{$_}}++ for @reasons }
        else
        {   error __x"unknown reason {which} in '{reasons}'"
              , which => $r, reasons => $reasons;
        }
    }
    (undef, @reasons)[sort {$a <=> $b} keys %r];
}

=function escape_chars STRING
Replace all escape characters into their readible counterpart.

=function unescape_chars STRING
Replace all C<\.> by their escape character.
=cut

my %unescape
 = ( '\a' => "\a", '\b' => "\b", '\f' => "\f", '\n' => "\n"
   , '\r' => "\r", '\t' => "\t", '\"' => '"', '\\\\' => '\\'
   , '\e' =>  "\x1b", '\v' => "\x0b"
   );
my %escape   = reverse %unescape;

sub escape_chars($)
{   my $str = shift;
    $str =~ s/([\x00-\x1F"\\])/$escape{$1} || '?'/ge;
    $str;
}

sub unescape_chars($)
{   my $str = shift;
    $str =~ s/(\\.)/$unescape{$1} || $1/ge;
    $str;
}

