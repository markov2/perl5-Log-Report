
use warnings;
use strict;

package Log::Report::Lexicon::PO;

use Log::Report 'log-report', syntax => 'SHORT';

# mixins
use Log::Report::Lexicon::POTcompact qw/_escape _unescape/;

=chapter NAME
Log::Report::Lexicon::PO - one translation definition

=chapter SYNOPSIS

=chapter DESCRIPTION
This module is administering one translation object.  Sets of PO
objects are kept in a POT file, implemented in M<Log::Report::Lexicon::POT>.

=chapter METHODS

=section Constructors

=c_method new OPTIONS

=requires msgid STRING

=option   msgid_plural STRING
=default  msgid_plural C<undef>

=option   msgstr STRING|ARRAY-OF-STRING
=default  msgstr "" or []
The translations for the msgid.  When msgid_plural is defined, then an
ARRAY must be provided.

=option   comment PARAGRAPH
=default  comment []
Translator added comments.
See M<addComment()>.

=option   fuzzy BOOLEAN
=default  fuzzy C<false>
The string is not yet translated, some smart guesses may have been made.
See M<fuzzy()>.

=option   automatic PARAGRAPH
=default  automatic ""
Automaticly added comments.
See M<addAutomatic()>.

=option   references STRING|ARRAY-OF-LOCATIONS
=default  references []
The STRING is a blank separated list of LOCATIONS.
LOCATIONs are of the  form C<filename:linenumber>, for
instance C<lib/Foo.pm:42>
See M<addReferences()>

=option   format ARRAY-OF-PAIRS|HASH
=default  format C<[]>
See M<format()>.
=cut

sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    defined($self->{msgid} = delete $args->{msgid})
       or error "no msgid defined for PO";

    $self->{plural} = delete $args->{msgid_plural};
    my $str         = delete $args->{msgstr};
    $self->{msgstr}
      = !defined $str       ? []
      : ref $str eq 'ARRAY' ? $str
      :                       [$str];

    $self->addComment(delete $args->{comment});
    $self->addAutomatic(delete $args->{automatic});
    $self->fuzzy(delete $args->{fuzzy});

    $self->{refs}   = {};
    $self->addReferences(delete $args->{references})
        if defined $args->{references};

    $self;
}

=section Attributes

=method msgid
Returns the actual msgid, which cannot be C<undef>.
=cut

sub msgid() {shift->{msgid}}

=method plural [STRING]
Returns the actual msgid_plural, which can be C<undef>.
=cut

sub plural(;$)
{   my $self = shift;
    @_ ? ($self->{plural} = shift) : $self->{plural};
}

=method msgstr [INDEX, [STRING]]
With a STRING, a new translation will be set.  Without STRING, a
lookup will take place.  When no plural is defined, use INDEX 0
=cut

sub msgstr($;$)
{   my $self = shift;
    return $self->{msgstr}[shift || 0]
       if @_ < 2;

    my ($nr, $string) = @_;
    $self->{msgstr}[$nr] = $string;
}

=method comment [LIST|ARRAY|STRING]
Returns a STRING which contains the cleaned paragraph of translator's
comment.  If an argument is specified, it will replace the current
comment.
=cut

sub comment(@)
{   my $self = shift;
    @_ or return $self->{comment};
    $self->{comment} = '';
    $self->addComment(@_);
}

=method addComment LIST|ARRAY|STRING
Add multiple lines to the translator's comment block.  Returns an
empty string if there are no comments.
=cut

sub addComment(@)
{   my $self    = shift;
    my $comment = $self->{comment};
    foreach my $line (ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_)
    {   defined $line or next;
        $line =~ s/[\r\n]+/\n/;  # cleanup line-endings
        $comment .= $line;
    }

    # be sure there is a \n at the end
    $comment =~ s/\n?\z/\n/ if defined $comment;
    $self->{comment} = $comment;
}

=method automatic [LIST|ARRAY|STRING]
Returns a STRING which contains the cleaned paragraph of automatically
added comments.  If an argument is specified, it will replace the current
comment.
=cut

sub automatic(@)
{   my $self = shift;
    @_ or return $self->{automatic};
    $self->{automatic} = '';
    $self->addAutomatic(@_);
}

=method addAutomatic LIST|ARRAY|STRING
Add multiple lines to the translator's comment block.  Returns an
empty string if there are no comments.
=cut

sub addAutomatic(@)
{   my $self = shift;
    my $auto = $self->{automatic};
    foreach my $line (ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_)
    {   defined $line or next;
        $line =~ s/[\r\n]+/\n/;  # cleanup line-endings
        $auto .= $line;
    }

    $auto =~ s/\n?\z/\n/ if defined $auto; # be sure there is a \n at the end
    $self->{automatic} = $auto;
}

=method references [STRING|LIST|ARRAY]
Returns an unsorted list of LOCATIONS.  When options are specified,
then those will be used to replace all currently defined references.
Returns the unsorted LIST of references.
=cut

sub references(@)
{   my $self = shift;
    if(@_)
    {   $self->{refs} = {};
        $self->addReferences(@_);
    }

    keys %{$self->{refs}};
}

=method addReferences STRING|LIST|ARRAY
The STRING is a blank separated list of LOCATIONS.  The LIST and
ARRAY contain separate LOCATIONs.  A LOCATION is of the form
C<filename:linenumber>.  Returns the internal HASH with references.
=cut

sub addReferences(@)
{   my $self = shift;
    my $refs = $self->{refs} ||= {};
    @_ or return $refs;

    $refs->{$_}++
       for @_ > 1               ? @_       # list
         : ref $_[0] eq 'ARRAY' ? @{$_[0]} # array
         : split " ",$_[0];                # scalar
    $refs;
}

=method removeReferencesTo FILENAME
Remove all the references to the indicate FILENAME from the list.  Returns
the number of refs left.
=cut

sub removeReferencesTo($)
{   my $refs  = $_[0]->{refs};
    my $match = qr/^\Q$_[1]\E\:\d+$/;
    $_ =~ $match && delete $refs->{$_}
        for keys %$refs;

    scalar keys %$refs;
}

=method isActive
Returns whether the translation has any references, or is the header.
=cut

sub isActive() { $_[0]->{msgid} eq '' || keys %{$_[0]->{refs}} }

=method fuzzy [BOOLEAN]
Returns whether the translation needs human inspection.
=cut

sub fuzzy(;$) {my $self = shift; @_ ? $self->{fuzzy} = shift : $self->{fuzzy}}

=method format LANGUAGE|PAIRS|ARRAY-OF-PAIRS|HASH
When one LANGUAGE is specified, it looks whether a C<LANGUAGE-format> or
C<no-LANGUAGE-format> is present in the line of FLAGS.  This will return
C<1> (true) in the first case, C<0> (false) in the second case.  It will
return C<undef> (also false) in case that both are not present.

You can also specify PAIRS: the key is a language name, and the
value is either C<0>, C<1>, or C<undef>.

=examples use of format()
 if($po->format('c')) ...
 unless($po->format('perl-brace')) ...
 if(defined $po->format('java')) ...

 $po->format(java => 1);       # results in 'java-format'
 $po->format(java => 0);       # results in 'no-java-format'
 $po->format(java => undef);   # results in ''
=cut

sub format(@)
{   my $format = shift->{format};
    return $format->{ (shift) }
        if @_==1 && !ref $_[0];  # language

    my @pairs = @_ > 1 ? @_ : ref $_[0] eq 'ARRAY' ? @{$_[0]} : %{$_[0]};
    while(@pairs)
    {   my($k, $v) = (shift @pairs, shift @pairs);
        $format->{$k} = $v;
    }
    $format;
}

=method addFlags STRING
Parse a "flags" line.
=cut

sub addFlags($)
{   my $self  = shift;
    local $_  = shift;
    my $where = shift;

    s/^\s+//;
    s/\s*$//;
    foreach my $flag (split /\s*\,\s*/)
    {      if($flag eq 'fuzzy') { $self->fuzzy(1) }
        elsif($flag =~ m/^no-(.*)-format$/) { $self->format($1, 0) }
        elsif($flag =~ m/^(.*)-format$/)    { $self->format($1, 1) }
        else
        {   warning __x"unknown flag {flag} ignored", flag => $flag;
        }
    }
    $_;
}
=section Parsing

=c_method fromText STRING, [WHERE]
Parse the STRING into a new PO object.  The WHERE string should explain
the location of the STRING, to be used in error messages.
=cut

sub fromText($$)
{   my $class = shift;
    my @lines = split /[\r\n]+/, shift;
    my $where = shift || ' unkown location';

    my $self  = bless {}, $class;

    # translations which are not used anymore are escaped with #~
    # however, we just say: no references found.
    s/^\#\~\s+// for @lines;

    my $last;
    foreach (@lines)
    {   chomp;
        if( s/^\#(.)\s?// )
        {      if($1 =~ /\s/) { $self->addComment($_)    }
            elsif($1 eq '.' ) { $self->addAutomatic($_)  }
            elsif($1 eq ':' ) { $self->addReferences($_) }
            elsif($1 eq ',' ) { $self->addFlags($_)      }
            else
            {   warning __x"unknown comment type '{cmd}' at {where}"
                  , cmd => "#$1", where => $where;
            }
            undef $last;
        }
        elsif( s/^\s*(\w+)\s+// )
        {   my $cmd    = $1;
            my $string = _unescape($_,$where);

            if($cmd eq 'msgid')
            {   $self->{msgid} = $string;
                $last = \($self->{msgid});
            }
            elsif($cmd eq 'msgid_plural')
            {   $self->{plural} = $string;
                $last = \($self->{plural});
            }
            elsif($cmd eq 'msgstr')
            {   $self->{msgstr} = [$string];
                $last = \($self->{msgstr}[0]);
            }
            else
            {   warning __x"do not understand command '{cmd}' at {where}"
                  , cmd => $cmd, where => $where;
                undef $last;
            }
        }
        elsif( s/^\s*msgstr\[(\d+)\]\s*// )
        {   my $nr = $1;
            $self->{msgstr}[$nr] = _unescape($_,$where);
        }
        elsif( m/^\s*\"/ )
        {   if(defined $last) { $$last .= _unescape($_,$where) }
            else
            {   warning __x"quoted line is not a continuation at {where}"
                 , where => $where;
            }
        }
        else
        {   warning __x"do not understand line at {where}:\n  {line}"
              , where => $where, line => $_;
        }
    }

    warning __x"no msgid in block {where}", where => $where
        unless defined $self->{msgid};

    $self;
}

=method toString OPTIONS
Format the object into a multi-lined string.

=option  nr_plurals INTEGER
=default nr_plurals C<undef>
If the number of plurals is specified, then the plural translation
list can be checked for the correct length.  Otherwise, no smart
behavior is attempted.
=cut

sub toString(@)
{   my ($self, %args) = @_;
    my $nplurals = $args{nr_plurals};
    my @text;

    my $comment = $self->comment;
    if(defined $comment && length $comment)
    {   $comment =~ s/^/#  /gm;
        push @text, $comment;
    }

    my $auto = $self->automatic;
    if(defined $auto && length $auto)
    {   $auto =~ s/^/#. /gm;
        push @text, $auto;
    }

    my @refs   = sort $self->references;
    my $msgid  = $self->{msgid} || '';
    my $active = $msgid eq '' || @refs ? '' : '#~ ';

    while(@refs)
    {   my $line = '#:';
        $line .= ' '.shift @refs
            while @refs && length($line) + length($refs[0]) < 80;
        push @text, "$line\n";
    }

    my @flags = $self->{fuzzy} ? 'fuzzy' : ();

    push @flags, ($self->{format}{$_} ? '' : 'no-') . $_ . '-format'
        for sort keys  %{$self->{format}};

    push @text, "#, ". join(", ", @flags) . "\n"
        if @flags;

    push @text, "${active}msgid "._escape($msgid, "\n$active")."\n"; 

    my @msgstr = @{$self->{msgstr} || []};
    my $plural = $self->{plural};
    if(defined $plural)
    {   push @text, "${active}msgid_plural "
                  . _escape($plural, "\n$active")
                  . "\n";

        push @msgstr, ''
            while defined $nplurals && @msgstr < $nplurals;

        if(defined $nplurals && @msgstr > $nplurals)
        {   warning __x"too many plurals for '{msgid}'", msgid => $msgid;
            $#msgstr = $nplurals -1;
        }

        $nplurals ||= 2;
        for(my $nr = 0; $nr < $nplurals; $nr++)
        {   push @text, "${active}msgstr[$nr] "
                        . _escape($msgstr[$nr], "\n$active") . "\n";
        }
    }
    else
    {   warning __x"no plurals for '{msgid}'", msgid => $msgid
            if @msgstr > 1;

        push @text, "${active}msgstr "
                  . _escape($msgstr[0], "\n$active")
                  . "\n";
    }

    join '', @text;
}

=method unused
The message-id has no references anymore and no translations.
=cut

sub unused()
{   my $self = shift;
    ! $self->references && ! $self->msgstr(0);
}

1;
