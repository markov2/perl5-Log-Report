
package Log::Report::Lexicon::Index;

use warnings;
use strict;

use File::Find  ();

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util  qw/parse_locale/;

# On windows, other locale names are used.  They will get translated
# into the Linux (ISO) convensions.

my $locale_unifier;
if($^O eq 'MSWin32')
{   require Log::Report::Win32Locale;
    Log::Report::Win32Locale->import;
    $locale_unifier = sub { iso_locale($_[0]) };
}
else
{   # some UNIXes do not understand "POSIX"
    $locale_unifier = sub { uc $_[0] eq 'POSIX' ? 'c' : lc $_[0] };
}

=chapter NAME
Log::Report::Lexicon::Index - search through available translation files

=chapter SYNOPSIS
 my $index = Log::Report::Lexicon::Index->new($directory);
 my $fn    = $index->find('my-domain', 'nl_NL.utf-8');

=chapter DESCRIPTION
This module handles the lookup of translation files for a whole
directory tree.  It is lazy loading, which means that it will only
build the search tree when addressed, not when the object is
created.

=chapter METHODS

=section Constructors

=c_method new DIRECTORY, OPTIONS
Create an index for a certain directory.  If the directory does not
exist, then the object will still be created.
=cut

sub new($;@)
{   my ($class, $dir) = (shift, shift);
    bless {dir => $dir, @_}, $class;  # dir before first argument.
}

=section Accessors

=method directory
Returns the directory name.
=cut

sub directory() {shift->{dir}}

=section Search

=method index
For internal use only.
Force the creation of the index (if not already done).  Returns a hash
with key-value pairs, where the key is the lower-cased version of the
filename, and the value the case-sensitive version of the filename.
=cut

sub index() 
{   my $self = shift;
    return $self->{index} if exists $self->{index};

    my $dir       = $self->directory;
    my $strip_dir = qr!\Q$dir/!;

    $self->{index} = {};
    File::Find::find
    ( +{ wanted   => sub
           { -f or return 1;
             (my $key = $_) =~ s/$strip_dir//;
             $self->addFile($key, $_);
             1;
           }
         , follow      => 1
         , no_chdir    => 1
         , follow_skip => 2
       } , $dir
    );

    $self->{index};
}

=method addFile BASENAME, [ABSOLUTE]
Add a certain file to the index.  This method returns the ABSOLUTE
path to that file, which must be used to access it.  When not explicitly
specified, the ABSOLUTE path will be calculated.
=cut

sub addFile($;$)
{   my ($self, $base, $abs) = @_;
    $abs ||= File::Spec->catfile($self->directory, $base);
    $base =~ s!\\!/!g;  # dos->unix
    $self->{index}{lc $base} = $abs;
}

=method find TEXTDOMAIN, LOCALE
Lookup the best translation table, according to the rules described
in chapter L</DETAILS>, below.

Returned is a filename, or C<undef> if nothing is defined for the
LOCALE (there is no default on this level).
=cut

# location to work-around platform dependent mutulations.
# may be extended with mo files as well.
sub _find($$) { $_[0]->{lc($_[1]). '.po'} }

sub find($$)
{   my $self   = shift;
    my $domain = lc shift;
    my $locale = $locale_unifier->(shift);

    my $index = $self->index;
    keys %$index or return undef;

    my ($lang, $terr, $cs, $modif) = parse_locale $locale;
    unless(defined $lang)
    {   defined $locale or $locale = '<undef>';
        # avoid problem with recursion, not translatable!
        print STDERR "illegal locale $locale, when looking for $domain";
        return undef;
    }

    $terr  = defined $terr  ? '_'.$terr  : '';
    $cs    = defined $cs    ? '.'.$cs    : '';
    $modif = defined $modif ? '@'.$modif : '';

    (my $normcs = $cs) =~ s/[^a-z\d]//g;
    if(length $normcs)
    {   $normcs = "iso$normcs" if $normcs !~ /\D/;
        $normcs = '.'.$normcs;
    }

    my $fn;
    for my $f ("/lc_messages/$domain", "/$domain")
    {   $fn
        ||= _find($index, "$lang$terr$cs$modif$f")
        ||  _find($index, "$lang$terr$normcs$modif$f")
        ||  _find($index, "$lang$terr$modif$f")
        ||  _find($index, "$lang$modif$f")
        ||  _find($index, "$lang$f");
    }

    $fn
    || _find($index, "$domain/$lang$terr$cs$modif")
    || _find($index, "$domain/$lang$terr$normcs$modif")
    || _find($index, "$domain/$lang$terr$modif")
    || _find($index, "$domain/$lang$modif")
    || _find($index, "$domain/$lang");
}

=method list DOMAIN, [EXTENSION]
Returned is a list of filenames which is used to update the list of
MSGIDs when source files have changed.  All translation files which
belong to a certain DOMAIN are listed.

The EXTENSION filter can be used to reduce the filenames further, for
instance to select only C<po> or only C<mo> files, and ignore readme's.
Use an string, without dot and interpreted case-insensitive, or a
regular expression.

=example
  my @l = $index->list('my-domain');
  my @l = $index->list('my-domain', 'po');
  my @l = $index->list('my-domain', qr/^readme/i);
=cut

sub list($;$)
{   my $self   = shift;
    my $domain = lc shift;
    my $filter = shift;
    my $index  = $self->index;
    my @list   = map $index->{$_}, grep m!\b\Q$domain\E\b!, keys %$index;

    defined $filter
        or return @list;

    $filter    = qr/\.\Q$filter\E$/i
        if defined $filter && ref $filter ne 'Regexp';

    grep $_ =~ $filter, @list;
}

=chapter DETAILS

It's always complicated to find the lexicon files, because the perl
package can be installed on any weird operating system.  Therefore,
you may need to specify the lexicon directory or alternative directories
explicitly.  However, you may also choose to install the lexicon files
in between the perl modules.

=section merge lexicon files with perl modules
By default, the filename which contains the package which contains the
textdomain's translator configuration is taken (that can be only one)
and changed into a directory name.  The path is then extended with C<messages>
to form the root of the lexicon: the top of the index.  After this,
the locale indication, the lc-category (usually LC_MESSAGES), and
the C<textdomain> followed by C<.po> are added.  This is exactly as
C<gettext(1)> does, but then using the PO text file instead of the MO
binary file.

=example lexicon in module tree
My module is named C<Some::Module> and installed in
some of perl's directories, say C<~perl5.8.8>.  The module is defining
textdomain C<my-domain>.  The translation is made into C<nl-NL.utf-8>
(locale for Dutch spoken in The Netherlands, utf-8 encoded text file).

The default location for the translation table is under
 ~perl5.8.8/Some/Module/messages/

for instance
 ~perl5.8.8/Some/Module/messages/nl-NL.utf-8/LC_MESSAGES/my-domain.po

There are alternatives, as described in M<Log::Report::Lexicon::Index>,
for instance
 ~perl5.8.8/Some/Module/messages/my-domain/nl-NL.utf-8.po
 ~perl5.8.8/Some/Module/messages/my-domain/nl.po

=section Locale search

The exact gettext defined format of the locale is
  language[_territory[.codeset]][@modifier]
The modifier will be used in above directory search, but only if provided
explicitly.

The manual C<info gettext> determines the rules.  During the search,
components of the locale get stripped, in the following order:
=over 4
=item 1. codeset
=item 2. normalized codeset
=item 3. territory
=item 4. modifier
=back

The normalized codeset (character-set name) is derived by
=over 4
=item 1. Remove all characters beside numbers and letters.
=item 2. Fold letters to lowercase.
=item 3. If the same only contains digits prepend the string "iso".
=back

To speed-up the search for the right table, the full directory tree
will be indexed only once when needed the first time.  The content of
all defined lexicon directories will get merged into one tree.

=section Example

My module is named C<Some::Module> and installed in some of perl's
directories, say C<~perl5>.  The module is defining textdomain
C<my-domain>.  The translation is made into C<nl-NL.utf-8> (locale for
Dutch spoken in The Netherlands, utf-8 encoded text file).

The translation table is taken from the first existing of these files:
  nl-NL.utf-8/LC_MESSAGES/my-domain.po
  nl-NL.utf-8/LC_MESSAGES/my-domain.po
  nl-NL.utf8/LC_MESSAGES/my-domain.po
  nl-NL/LC_MESSAGES/my-domain.po
  nl/LC_MESSAGES/my-domain.po

Then, attempts are made which are not compatible with gettext.  The
advantage is that the directory structure is much simpler.  The idea
is that each domain has its own locale installation directory, instead
of everything merged in one place, what gettext presumes.

In order of attempts:
  nl-NL.utf-8/my-domain.po
  nl-NL.utf8/my-domain.po
  nl-NL/my-domain.po
  nl/my-domain.po
  my-domain/nl-NL.utf8.po
  my-domain/nl-NL.po
  my-domain/nl.po

Filenames may get mutilated by the platform (which we will try to hide
from you [please help improve this]), and are treated case-INsensitive!
=cut

1;
