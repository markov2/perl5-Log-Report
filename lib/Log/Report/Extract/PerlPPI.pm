
use warnings;
use strict;

package Log::Report::Extract::PerlPPI;

use Log::Report 'log-report', syntax => 'SHORT';

use Log::Report::Lexicon::Index ();
use Log::Report::Lexicon::POT   ();

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

=chapter NAME
Log::Report::Extract::PerlPPI - Collect translatable strings from Perl using PPI

=chapter SYNOPSIS
 my $ppi = Log::Report::Extract::PerlPPI->new
  ( lexicon => '/usr/share/locale'
  );
 $ppi->process('lib/My/Pkg.pm');  # many times
 $ppi->showStats;   # to dispatchers which accept TRACE or INFO
 $ppi->write;       # also cleans processing memory.

=chapter DESCRIPTION
This module helps maintaining the POT files, updating the list of
message-ids which are kept in them.  After initiation, the M<process()>
method needs to be called with all files which changed since last processing
and the existing PO files will get updated accordingly.  If no translations
exist yet, one C<textdomain/xx.po> file will be created.

=chapter METHODS

=section Constructors

=c_method new OPTIONS
=requires lexicon DIRECTORY
The place where the lexicon is kept.  When no lexicon is defined yet,
this will be the directory where an C<domain/xx.po> file will be created.

=option  charset STRING
=default charset 'utf-8'
The character-set used in the PO files.

=cut

sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    my $lexi = $args->{lexicon}
        or error __"PerlPPI requires explicit lexicon directory";

    -d $lexi or mkdir $lexi
        or fault __x"cannot create lexicon directory {dir}", dir => $lexi;

    $self->{index}   = Log::Report::Lexicon::Index->new($lexi);
    $self->{charset} = $args->{charset} || 'utf-8';
    $self;
}

=section Accessors

=method index
Returns the M<Log::Report::Lexicon::Index> object, which is listing
the files in the lexicon directory tree.

=method charset
Returns the character-set used inside the POT files.

=method domains
Returns a sorted list of all known domain names.
=cut

sub index()   {shift->{index}}
sub charset() {shift->{charset}}
sub domains() {sort keys %{shift->{domains}}}

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
    info __x"processing file {fn} in {charset}", fn=> $fn, charset => $charset;

    $charset eq 'iso-8859-1'
        or error __x"PPI only supports iso-8859-1 (latin-1) on the moment";

    my $doc = PPI::Document->new($fn, readonly => 1)
        or fault __x"cannot read from file {filename}", filename => $fn;

    my ($pkg, $include, $domain) = ('main', 0, undef);

  NODE:
    foreach my $node ($doc->schildren)
    {   if($node->isa('PPI::Statement::Package'))
        {   $pkg     = $node->namespace;

            # special hack for module Log::Report itself
            if($pkg eq 'Log::Report')
            {   ($include, $domain) = (1, 'log-report');
                $self->_reset($domain, $fn);
            }
            else { ($include, $domain) = (0, undef) }

            next NODE;
        }

        if($node->isa('PPI::Statement::Include'))
        {   next NODE if $node->type ne 'use' || $node->module ne 'Log::Report';
            $include++;
            my $dom = ($node->schildren)[2];
            $domain = $dom->isa('PPI::Token::Quote') ? $dom->string : undef;
            $self->_reset($domain, $fn);
        }

        $node->find_any
         ( sub { # look for the special translation markers
                 $_[1]->isa('PPI::Token::Word') or return 0;

                 my $node = $_[1];
                 my $def  = $msgids{$node->content}
                     or return 0;

                 my @msgids = $self->_get($node, @$def)
                     or return 0;

                 my $line = $node->location->[0];
                 unless($domain)
                 {   mistake __x
                         "no textdomain for translatable at {fn} line {line}"
                        , fn => $fn, line => $line;
                     return 0;
                 }

                 if($def->[4]) # split
                 {   $self->_store($domain, $fn, $line, $_)
                        for map {split} @msgids;
                 }
                 else
                 {   $self->_store($domain, $fn, $line, @msgids);
                 }

                 0;  # don't collect
               }
         );
    }
}

sub _get($$$$$)
{   my ($self, $node, $msgids, $count, $opts, $vars, $split) = @_;
    my $list_only = ($msgids > 1) || $count || $opts || $vars;
    my $expand    = $opts || $vars;

    my @msgids;
    my $first     = $node->snext_sibling;
    $first = $first->schild(0)
        if $first->isa('PPI::Structure::List');

    $first = $first->schild(0)
        if $first->isa('PPI::Statement::Expression');

    while(defined $first && $msgids > @msgids)
    {   my $msgid;
        my $next  = $first->snext_sibling;
        my $sep   = $next && $next->isa('PPI::Token::Operator') ? $next : '';
        my $line  = $first->location->[0];

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
          , line => $line if $msgid =~ s/(?<!\\)\n$//;

        push @msgids, $msgid;
        last if $msgids==@msgids || !$sep;

        $first = $sep->snext_sibling;
    }

    @msgids;
}

=method showStats [DOMAINs]
Show a status about the DOMAIN (by default all domains).  At least mode
verbose is required to see this.
=cut

sub showStats(;$)
{   dispatcher needs => 'INFO'
        or return;

    my $self = shift;
    my @domains = @_ ? @_ : $self->domains;

    foreach my $domain (@domains)
    {   my $pots = $self->{domains}{$domain} or next;
        my ($msgids, $fuzzy, $inactive) = (0, 0, 0);

        foreach my $pot (@$pots)
        {   my $stats = $pot->stats;
            next unless $stats->{fuzzy} || $stats->{inactive};

            $msgids   = $stats->{msgids};
            next if $msgids == $stats->{fuzzy};   # ignore the template

            notice __x
                "{domain}: {fuzzy%3d} fuzzy, {inact%3d} inactive in {filename}"
              , domain => $domain, fuzzy => $stats->{fuzzy}
              , inact => $stats->{inactive}, filename => $pot->filename;

            $fuzzy    += $stats->{fuzzy};
            $inactive += $stats->{inactive};
        }

        if($fuzzy || $inactive)
        {   info __xn
"{domain}: one file with {ids} msgids, {f} fuzzy and {i} inactive translations"
, "{domain}: {_count} files each {ids} msgids, {f} fuzzy and {i} inactive translations in total"
              , scalar(@$pots), domain => $domain
              , f => $fuzzy, ids => $msgids, i => $inactive
        }
        else
        {   info __xn
                "{domain}: one file with {ids} msgids"
              , "{domain}: {_count} files with each {ids} msgids"
              , scalar(@$pots), domain => $domain, ids => $msgids;
        }
    }
}

=method write [DOMAIN]
Update the information of the files related to DOMAIN, by default all
processed DOMAINS.  All information known about the DOMAIN is removed
from the cache.
=cut

sub write(;$)
{   my ($self, $domain) = @_;
    unless(defined $domain)  # write all
    {   $self->write($_) for keys %{$self->{domains}};
        return;
    }

    my $pots = delete $self->{domains}{$domain}
        or return;  # nothing found

    for my $pot (@$pots)
    {   $pot->updated;
        $pot->write;
    }

    $self;
}

sub DESTROY() {shift->write}

sub _reset($$)
{   my ($self, $domain, $fn) = @_;

    my $pots = $self->{domains}{$domain}
           ||= $self->_read_pots($domain);

    $_->removeReferencesTo($fn) for @$pots;
}

sub _read_pots($)
{   my ($self, $domain) = @_;

    my $index   = $self->index;
    my $charset = $self->charset;

    my @pots = map {Log::Report::Lexicon::POT->read($_, charset=> $charset)}
        $index->list($domain);

    trace __xn "found one pot file for domain {domain}"
             , "found {_count} pot files for domain {domain}"
             , @pots, domain => $domain;

    @pots && return \@pots;

    # new textdomain
    my $fn = $index->addFile("$domain.$charset.po");
    info __x"starting new textdomain {domain}, template in {filename}"
       , domain => $domain, filename => $fn;

    my $pot = Log::Report::Lexicon::POT->new
     ( textdomain => $domain
     , filename   => $fn
     , charset    => $charset
     , version    => 0.01
     );

    [ $pot ];
}

sub _store($$$$;$)
{   my ($self, $domain, $fn, $linenr, $msgid, $plural) = @_;

    foreach my $pot ( @{$self->{domains}{$domain}} )
    {   if(my $po = $pot->msgid($msgid))
        {   $po->addReferences( ["$fn:$linenr"]);
            $po->plural($plural) if $plural;
            next;
        }

        my $format = $msgid =~ m/\{/ ? 'perl-brace' : 'perl';
        my $po = Log::Report::Lexicon::PO->new
          ( msgid        => $msgid
          , msgid_plural => $plural
          , fuzzy        => 1
          , format       => $format
          , references   => [ "$fn:$linenr" ]
          );

        $pot->add($po);
    }
}

1;
