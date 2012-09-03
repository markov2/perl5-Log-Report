
use warnings;
use strict;

package Log::Report::Extract::Template;
use base 'Log::Report::Extract';

use Log::Report 'log-report';

=chapter NAME
Log::Report::Extract::Template - Collect translatable strings from templates

=chapter SYNOPSIS
 my $extr = Log::Report::Extract::Template->new
  ( lexicon => '/usr/share/locale'
  , domain  => 'my-web-site'
  , pattern => 'TT2-loc'
  );
 $extr->process('website/page.html');  # many times
 $extr->showStats;
 $extr->write;

 # See script  xgettext-perl

=chapter DESCRIPTION
This module helps maintaining the POT files which list translatable
strings from template files by updating the list of message-ids which
are kept in them.

After initiation, the M<process()> method needs to be called with
all files which changed since last processing and the existing PO
files will get updated accordingly.  If no translations exist yet,
one C<textdomain/xx.po> file will be created.

=chapter METHODS

=section Constructors

=c_method new OPTIONS

=requires domain DOMAIN
There is no syntax for specifying domains in templates (yet), so you
must be explicit about the collection we are making now.

=option  pattern PREDEFINED|REGEX
=default pattern <undef>
See the DETAILS section below for a detailed explenation.
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{LRET_domain}  = $args->{domain}
        or error "template extract requires explicit domain";

    $self->{LRET_pattern} = $self->_pattern($args->{pattern});
    $self;
}

=section Accessors
=method domain
=method pattern
=cut

sub domain()  {shift->{LRET_domain}}
sub pattern() {shift->{LRET_pattern}}

=section Processors

=method process FILENAME, OPTIONS
Update the domains mentioned in the FILENAME.  All textdomains defined
in the file will get updated automatically, but not written before
all files where processed.

=option  charset STRING
=default charset 'utf-8'
The character encoding used in this template file.

=option  pattern PREDEFINED|REGEX
=default pattern <from new(pattern)>
Read the DETAILS section about this.
=cut

sub process($@)
{   my ($self, $fn, %opts) = @_;

    my $charset = $opts{charset} || 'utf-8';
    info __x"processing file {fn} in {charset}", fn=> $fn, charset => $charset;

    # Slurp the whole file
    local *IN;
    open IN, "<:encoding($charset)", $fn
        or fault __x"cannot read template from {fn}", fn => $fn;

    undef $/;
    my $text = <IN>;
    close IN;

    my $domain  = $self->domain;
    $self->_reset($domain, $fn);

    my $pattern = $self->_pattern($opts{pattern}) || $self->pattern
        or error __"need pattern to scan for, either via new() or process()";

    # Split the whole file on the pattern in four fragments per match:
    #       (text, leading, needed trailing, text, leading, ...)
    # f.i.  ('', '[% loc("', 'some-msgid', '", params) %]', ' more text')
    my @frags      = split $pattern, $text;

    my $linenr     = 1;
    my $msgs_found = 0;

    while(@frags > 4)
    {   $linenr += ($frags[0] =~ tr/\n//)   # text
                +  ($frags[1] =~ tr/\n//);  # leading
        (my $msgid = $frags[2]) =~ s/^(['"]*)(.*?)\1/$2/;
        my $plural = $msgid =~ s/\|(.*)// ? $1 : undef;
        $self->store($domain, $fn, $linenr, $msgid, $plural);
        $msgs_found++;
        $linenr += ($frags[2] =~ tr/\n//)
                +  ($frags[3] =~ tr/\n//);
        splice @frags, 0, 4;
    }

    $msgs_found;
}

#----------------------------------------------------
=chapter DETAILS

=section Scan Patterns

Various template systems use different conventions for denoting strings
to be translated.

=subsection Your own regular expression

If you do not have a format which is predefined, then you can pass-in
your own regular expression.  Be sure it captures three components:
the beginning of the markup, the msgid to be included in the translation
table, and the ending of the markup.

Example:

   pattern => qr/(<")(.*?)(">)/

This would match

   <"Hello, World">

The markup compenents must contain all allowed white-spacing, to be able
to produce the correct line-numbers.  Enclosing single and double quotes
aroung the msgid will get removed, if still present after the match.

This example is simplifying too much: your syntax should support parameters
and messages which can be in singular or plural form.  The next section
shows a sufficiently powerful syntax.

=subsection Predefined for Template::Toolkit

There is not a single convertion for translations in M<Template::Toolkit>,
so you need to specify which version you use and which function you want
to run.

For instance

   pattern => 'TT2-loc'

will scan for

   [% loc("msgid", key => value, ...) %]
   [% loc('msgid', key => value, ...) %]
   [% loc("msgid|plural", count, key => value, ...) %]

For TT1, the brackets can either be '[%...%]' or '%%...%%'.  The function
name is treated case-sensitive.  Some people prefer 'l()'.

The code needed

   ... during initiation of the webserver
   my $lexicons   = 'some-directory-for-translation-tables';
   my $translator = Log::Report::Translator::POT->new(lexicons => $lexicons);
   Log::Report->translator($textdomain => $translator);

   ... your template driver
   sub handler {
      ...
      my $fill_in     = { ...all kinds of values... };
      $fill_in->{loc} = \&translate;    # this is extra

      my $output      = '';
      my $templater   = Template->new(...);
      $templater->process($template_fn, $fill_in, \$output);
      print $output;
   }

   ... anywhere in the same file
   sub translate {
       my $textdomain = ...;   # specified with xgettext-perl
       my $lang       = ...;   # how do you figure that out?
       my $msg = Log::Report::Message->fromTemplateToolkit($textdomain, @_);
       $msg->toString($lang);
   }

   ... to generate the pod tables, run in the shell something like
   xgettext-perl -p $lexicons --template TT2-loc \
      --domain $textdomain  templates/

=cut

sub _pattern($)
{   my ($self, $pattern) = @_;

    return $pattern
        if !defined $pattern || ref $pattern eq 'Regexp';

    if($pattern =~ m/^TT([12])-(\w+)$/)
    {    # Recognized is Template::Toolkit 2
         my ($level, $function) = ($1, $2);
         my ($open, $close) = $level==1 ? ('[\[%]%', '%[\]%]') : ('\[%', '%\]');

         return qr/( $open \s* \Q$function\E \s* \( \s* ) # leading
                   ( "[^"\n]*" | '[^'\n]*' )              # msgid
                   ( .*?                                  # params
                     $close )                             # ending
                  /xs;
    }

    error __x"scan pattern `{pattern}' not recognized", pattern => $pattern;
}

1;
