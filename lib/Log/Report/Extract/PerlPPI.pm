
use warnings;
use strict;

package Log::Report::Extract::PerlPPI;
use base 'Log::Report::Extract';

use Log::Report 'log-report';
use PPI;

# See Log::Report translation markup functions
my %msgids =
 #         MSGIDs COUNT OPTS VARS SPLIT
 ( __   => [1,    0,    0,   0,   0]
 , __x  => [1,    0,    1,   1,   0]
 , __xn => [2,    1,    1,   1,   0]
 , __n  => [2,    1,    1,   0,   0]
 , N__  => [1,    0,    1,   1,   0]  # may be used with opts/vars
 , N__n => [2,    0,    1,   1,   0]  # idem
 , N__w => [1,    0,    0,   0,   1]
 );

my $quote_mistake;
{   my @q    = map quotemeta, keys %msgids;
    local $" = '|';
    $quote_mistake = qr/^(?:@q)\'/;
}

=chapter NAME
Log::Report::Extract::PerlPPI - Collect translatable strings from Perl using PPI

=chapter SYNOPSIS
 my $ppi = Log::Report::Extract::PerlPPI->new
  ( lexicon => '/usr/share/locale'
  );
 $ppi->process('lib/My/Pkg.pm');  # call for each .pm file
 $ppi->showStats;                 # optional
 $ppi->write;

 # See script  xgettext-perl

=chapter DESCRIPTION

This module helps maintaining the POT files, updating the list of
message-ids which are kept in them.  After initiation, the M<process()>
method needs to be called with all files which changed since last processing
and the existing PO files will get updated accordingly.

If no translations exist yet, one C<$lexicon/$domain.po> file will be
created.  If you want to start a translation, copy C<$lexicon/$domain.po>
to C<$lexicon/$domain/$lang.po> and edit that file.  You may use
C<poedit> to edit po-files.  Do not forget to add the new po-file to
your distribution (MANIFEST)

=section The extraction process

All pm-files need to be processed in one go: no incremental processing!

The Perl source is parsed using M<PPI>, which does understand Perl syntax
quite well, but does not support all features.

Automatically, the textdomain of the translations is discovered, as
first parameter of C<use Log::Report>.  You may switch textdomain inside
one pm-file.

When all files have been processed, during the M<write()>, all existing
po-files for all discovered textdomains will get updated.  Not only the
C<$lexicon/$domain.po> template, but also all C<$lexicon/$domain/$lang.po>
will be replaced.  When a msgid has disappeared, existing translations
will get disabled, not removed.  New msgids will be added and flagged
"fuzzy".

=subsection What is extracted?

This script will extract the msgids used in C<__()>, C<__x()>, C<__xn()>,
and C<__n()> (implemented by M<Log::Report>) For instance

  __x"msgid", @more
  __x'msgid', @more  <--- no!  syntax error!
  __x("msgid", @more)
  __x('msgid', @more)
  __x(msgid => @more)

Besides, there are some helpers which are no-ops in the code, only to fill
the po-tables: C<N__()>, C<N__n()>, C<N__()>

=subsection What is not extracted?

B<Not> extracted are the usage of anything above, where the first
parameter is not a simple string.  Not extracted are

  __x($format, @more)
  __x$format, @more
  __x(+$format, _domain => 'other domain', @more)
  __x($first.$second, @more)

In these cases, you have to use C<N__()> functions to declare the possible
values of C<$format>.

=chapter METHODS

=section Constructors

=section Accessors

=section Processors

=method process FILENAME, OPTIONS
Update the domains mentioned in the FILENAME.  All textdomains defined
in the file will get updated automatically, but not written before
all files where processed.

=option  charset STRING
=default charset 'iso-8859-1'
=cut

sub process($@)
{   my ($self, $fn, %opts) = @_;

    my $charset = $opts{charset} || 'iso-8859-1';

    $charset eq 'iso-8859-1'
        or error __x"PPI only supports iso-8859-1 (latin-1) on the moment";

    my $doc = PPI::Document->new($fn, readonly => 1)
        or fault __x"cannot read perl from file {filename}", filename => $fn;

    my @childs = $doc->schildren;
    if(@childs==1 && ref $childs[0] eq 'PPI::Statement')
    {   info __x"no Perl in file {filename}", filename => $fn;
        return 0;
    }

    info __x"processing file {fn} in {charset}", fn=> $fn, charset => $charset;
    my ($pkg, $include, $domain, $msgs_found) = ('main', 0, undef, 0);

  NODE:
    foreach my $node ($doc->schildren)
    {   if($node->isa('PPI::Statement::Package'))
        {   $pkg     = $node->namespace;

            # special hack needed for module Log::Report itself
            if($pkg eq 'Log::Report')
            {   ($include, $domain) = (1, 'log-report');
                $self->_reset($domain, $fn);
            }
            else { ($include, $domain) = (0, undef) }
            next NODE;
        }

        if($node->isa('PPI::Statement::Include'))
        {   $node->type eq 'use' && $node->module eq 'Log::Report'
                or next NODE;

            $include++;
            my $dom = ($node->schildren)[2];
            $domain
               = $dom->isa('PPI::Token::Quote')            ? $dom->string
               : $dom->isa('PPI::Token::QuoteLike::Words') ? ($dom->literal)[0]
               : undef;

            $self->_reset($domain, $fn);
        }

        $node->find_any( sub {
            # look for the special translation markers
            $_[1]->isa('PPI::Token::Word') or return 0;

            my $node = $_[1];
            my $word = $node->content;
            if($word =~ $quote_mistake)
            {   warning __x"use double quotes not single, in {string} on {file} line {line}"
                  , string => $word, fn => $fn, line => $node->location->[0];
                return 0;
            }

            my $def  = $msgids{$word}  # get __() description
                or return 0;

            my @msgids = $self->_get($node, $domain, $word, $def)
                or return 0;

            my ($nr_msgids, $has_count, $has_opts, $has_vars,$do_split) = @$def;

            my $line = $node->location->[0];
            unless($domain)
            {   mistake
                    __x"no text-domain for translatable at {fn} line {line}"
                  , fn => $fn, line => $line;
                return 0;
            }

            if($do_split)    #  Bulk conversion strings
            {   my @words = map {split} @msgids;
                $self->store($domain, $fn, $line, $_) for @words;
                $msgs_found += @words;
            }
            else
            {   $self->store($domain, $fn, $line, @msgids);
                $msgs_found += 1;
            }

            0;  # don't collect
       });
    }

    $msgs_found;
}

sub _get($$$$)
{   my ($self, $node, $domain, $function, $def) = @_;
    my ($nr_msgids, $has_count, $opts, $vars, $split) = @$def;
    my $list_only = ($nr_msgids > 1) || $has_count || $opts || $vars;
    my $expand    = $opts || $vars;

    my @msgids;
    my $first     = $node->snext_sibling;
    $first = $first->schild(0)
        if $first->isa('PPI::Structure::List');

    $first = $first->schild(0)
        if $first->isa('PPI::Statement::Expression');

    my $line;
    while(defined $first && $nr_msgids > @msgids)
    {   my $msgid;
        my $next  = $first->snext_sibling;
        my $sep   = $next && $next->isa('PPI::Token::Operator') ? $next : '';
        $line     = $first->location->[0];

        if($first->isa('PPI::Token::Quote'))
        {   last if $sep !~ m/^ (?: | \=\> | [,;:] ) $/x;
            $msgid = $first->string;

            if(  $first->isa("PPI::Token::Quote::Double")
              || $first->isa("PPI::Token::Quote::Interpolate"))
            {   mistake __x
                   "do not interpolate in msgid (found '{var}' in line {line})"
                   , var => $1, line => $line
                      if $first->string =~ m/(?<!\\)(\$\w+)/;

                # content string is uninterpreted, warnings to screen
                $msgid = eval "qq{$msgid}";

                error __x "string is incorrect at line {line}: {error}"
                   , line => $line, error => $@ if $@;
            }
        }
        elsif($first->isa('PPI::Token::Word'))
        {   last if $sep ne '=>';
            $msgid = $first->content;
        }
        else {last}

        mistake __x "new-line is added automatically (found in line {line})"
          , line => $line if !$split && $msgid =~ s/(?<!\\)\n$//;

        push @msgids, $msgid;
        last if $nr_msgids==@msgids || !$sep;

        $first = $sep->snext_sibling;
    }
    @msgids or return ();
    my $next = $first->snext_sibling;
    if($has_count && !$next)
    {   error __x"count missing in {function} in line {line}"
           , function => $function, line => $line;
    }

    @msgids;
}

1;
