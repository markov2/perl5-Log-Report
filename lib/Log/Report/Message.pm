use warnings;
use strict;

package Log::Report::Message;

use Log::Report 'log-report';
use POSIX      qw/locale_h/;
use List::Util qw/first/;

=chapter NAME
Log::Report::Message - a piece of text to be translated

=chapter SYNOPSIS
 # Created by Log::Report's __ functions
 # Full feature description in the DETAILS section

 # no interpolation
 __"Hello, World";

 # with interpolation
 __x"age {years}", years => 12;

 # interpolation for one or many
 my $nr_files = @files;
 __nx"one file", "{_count} files", $nr_files;
 __nx"one file", "{_count} files", \@files;

 # interpolation of arrays
 __x"price-list: {prices%.2f}", prices => \@prices, _join => ', ';

 # white-spacing on msgid preserved
 print __"\tCongratulations,\n";
 print "\t", __("Congratulations,"), "\n";  # same

=chapter DESCRIPTION
Any use of a translation function exported by M<Log::Report>, like
C<__()> (the function is named underscore-underscore) or C<__x()>
(underscore-underscore-x) will result in this object.  It will capture
some environmental information, and delay the translation until it
is needed.

Creating an object first and translating it later, is slower than
translating it immediately.  However, on the location where the message
is produced, we do not yet know in what language to translate it to:
that depends on the front-end, the log dispatcher.

=chapter OVERLOADING

=overload stringification
When the object is used in string context, it will get translated.
Implemented as M<toString()>.

=overload as function
When the object is used to call as function, a new object is
created with the data from the original one but updated with the
new parameters.  Implemented in C<clone()>.

=overload concatenation
An (accidental) use of concatenation (a dot where a comma should be
used) would immediately stringify the object.  This is avoided by
overloading that operation.
=cut

use overload
    '""'  => 'toString'
  , '&{}' => sub { my $obj = shift; sub{$obj->clone(@_)} }
  , '.'   => 'concat';

=chapter METHODS

=section Constructors

=c_method new OPTIONS
B<End-users: do not use this method directly>, but use M<Log::Report::__()>
and friends.  The OPTIONS is a mixed list of object initiation parameters
(all with a leading underscore) and variables to be filled in into the
translated C<_msgid> string.

=option  _expand BOOLEAN
=default _expand C<false>
Indicates whether variables are to be filled-in.

=option  _domain STRING
=default _domain <from "use Log::Report">
The text-domain (translation table) to which this C<_msgid> belongs.

With this parameter, your can "borrow" translations from other textdomains.
Be very careful with this (although there are good use-cases)  The xgettext
msgid extractor may add the used msgid to this namespace as well.  To
avoid that, add a harmless '+':

  print __x(+"errors", _domain => 'global');

The extractor will not take the msgid when it is an expression.  The '+'
has no effect on the string at runtime.

=option  _count INTEGER|ARRAY|HASH
=default _count C<undef>
When defined, the C<_plural> need to be defined as well.  When an
ARRAY is provided, the length of the ARRAY is taken.  When a HASH
is given, the number of keys in the HASH is used.

=option  _plural MSGID
=default _plural C<undef>
Can be used together with C<_count>.  This plural form of the C<_msgid>
text is used to simplify the work of translators, and as fallback when
no translation is possible: therefore, this can best resemble an
English message.

White-space at the beginning and end of the string are stripped off.
The white-space provided by the C<_msgid> will be used.

=option  _msgid MSGID
=default _msgid C<undef>
The message label, which refers to some translation information.
Usually a string which is close the English version of the message.
This will also be used if there is no translation possible/known.

Leading white-space C<\s> will be added to C<_prepend>.  Trailing
white-space will be added before C<_append>.

=option  _category INTEGER
=default _category C<undef>
The category when the real gettext library is used, for instance
LC_MESSAGES.

=option  _prepend STRING|MESSAGE
=default _prepend C<undef>
Text as STRING or MESSAGE object to be displayed before the display
of this message.

=option  _append  STRING|MESSAGE
=default _append  C<undef>
Text as STRING or MESSAGE object to be displayed after the display
of this message.

=option  _class   STRING|ARRAY
=default _class   []
When messages are used for exception based programming, you add
C<_class> parameters to the argument list.  Later, with for instance
M<Log::Report::Dispatcher::Try::wasFatal(class)>, you can check the
category of the message.

One message can be part of multiple classes.  The STRING is used as
comma- and/or blank separated list of class tokens (barewords), the
ARRAY lists all tokens separately. See M<classes()>.

=option  _classes STRING|ARRAY
=default _classes []
Alternative for C<_class>, which cannot be used at the same time.

=option  _to NAME
=default _to <undef>
Specify the NAME of a dispatcher as destination explicitly. Short
for  C<< report {to => NAME}, ... >>  See M<to()>

=option  _join STRING
=default _join C<$">  C<$LIST_SEPARATOR>
Which STRING to be used then an ARRAY is being filled-in.
=cut

sub new($@)
{   my ($class, %s) = @_;

    if(ref $s{_count})
    {   my $c        = $s{_count};
        $s{_count}   = ref $c eq 'ARRAY' ? @$c : keys %$c;
    }

    defined $s{_join}
        or $s{_join} = $";

    if($s{_msgid})
    {   $s{_append}  = defined $s{_append} ? $1.$s{_append} : $1
            if $s{_msgid} =~ s/(\s+)$//;

        $s{_prepend}.= $1
            if $s{_msgid} =~ s/^(\s+)//;
    }
    if($s{_plural})
    {   s/\s+$//, s/^\s+// for $s{_plural};
    }
    bless \%s, $class;
}

=method clone OPTIONS, VARIABLES
Returns a new object which copies info from original, and updates it
with the specified OPTIONS and VARIABLES.  The advantage is that the
cached translations are shared between the objects.

=examples use of clone()
 my $s = __x "found {nr} files", nr => 5;
 my $t = $s->clone(nr => 3);
 my $t = $s->(nr => 3);      # equivalent
 print $s;     # found 5 files
 print $t;     # found 3 files
=cut

sub clone(@)
{   my $self = shift;
    (ref $self)->new(%$self, @_);
}

=c_method fromTemplateToolkit DOMAIN, MSGID, PARAMS
See M<Log::Report::Extract::Template> on the details how to integrate
Log::Report translations with Template::Toolkit (version 1 and 2)
=cut

sub fromTemplateToolkit($$;@)
{   my ($class, $domain, $msgid) = splice @_, 0, 3;
    my $plural = $msgid =~ s/\|(.*)// ? $1 : undef;
    my $args   = @_ && ref $_[-1] eq 'HASH' ? pop : {};

    my $count;
    if(defined $plural)
    {   @_==1 or $msgid .= " (ERROR: missing count for plural)";
        $count = shift || 0;
        $count = @$count if ref $count eq 'ARRAY';
    }
    else
    {   @_==0 or $msgid .= " (ERROR: only named parameters expected)";
    }

    $class->new
      ( _msgid => $msgid, _plural => $plural, _count => $count
      , %$args, _expand => 1, _domain => $domain);
}

=section Accessors

=method prepend
Returns the string which is prepended to this one.  Usually C<undef>.

=method msgid
Returns the msgid which will later be translated.

=method append
Returns the string or M<Log::Report::Message> object which is appended
after this one.  Usually C<undef>.

=method domain
Returns the domain of the first translatable string in the structure.

=method count
Returns the count, which is used to select the translation
alternatives.
=cut

sub prepend() {shift->{_prepend}}
sub msgid()   {shift->{_msgid}}
sub append()  {shift->{_append}}
sub domain()  {shift->{_domain}}
sub count()   {shift->{_count}}

=method classes
Returns the LIST of classes which are defined for this message; message
group indicators, as often found in exception-based programming.
=cut

sub classes()
{   my $class = $_[0]->{_class} || $_[0]->{_classes} || [];
    ref $class ? @$class : split(/[\s,]+/, $class);
}

=method to [NAME]
Returns the NAME of a dispatcher if explicitly specified with
the '_to' key. Can also be used to set it.  Usually, this will
return undef, because usually all dispatchers get all messages.
=cut

sub to(;$)
{   my $self = shift;
    @_ ? $self->{_to} = shift : $self->{_to};
}

=method valueOf PARAMETER
Lookup the named PARAMETER for the message.  All pre-defined names
have their own method which should be used with preference.

=example
When the message was produced with

  my @files = qw/one two three/;
  my $msg = __xn "found one file: {file}"
               , "found {nrfiles} files: {files}"
               , scalar @files
               , file    => $files[0]
               , files   => \@files
               , nrfiles => @files+0
               , _class  => 'IO, files'
               , _join   => ', ';

then the values can be takes from the produced message as

  my $files = $msg->valueOf('files');  # returns ARRAY reference
  print @$files;              # 3
  my $count = $msg->count;    # 3
  my @class = $msg->classes;  # 'IO', 'files'
  if($msg->inClass('files'))  # true

Simplified, the above example can also be written as:

  local $" = ', ';
  my $msg  = __xn "found one file: {files}"
                , "found {_count} files: {files}"
                , @files      # has scalar context
                , files   => \@files
                , _class  => 'IO, files';


=cut

sub valueOf($) { $_[0]->{$_[1]} }

=section Processing

=method inClass CLASS|REGEX
Returns true if the message is in the specified CLASS (string) or
matches the REGEX.  The trueth value is the (first matching) class.
=cut

sub inClass($)
{   my @classes = shift->classes;
       ref $_[0] eq 'Regexp'
    ? (first { $_ =~ $_[0] } @classes)
    : (first { $_ eq $_[0] } @classes);
}
    
=method toString [LOCALE]
Translate a message.  If not specified, the default locale is used.
=cut

sub toString(;$)
{   my ($self, $locale) = @_;
    my $count  = $self->{_count} || 0;

    $self->{_msgid}   # no translation, constant string
        or return (defined $self->{_prepend} ? $self->{_prepend} : '')
                . (defined $self->{_append}  ? $self->{_append}  : '');

    # create a translation
    my $text = Log::Report->translator($self->{_domain})
      ->translate($self, $locale);
  
    defined $text or return ();

    my $oldloc;
    if(defined $locale)
    {   $oldloc = setlocale(LC_ALL);
        setlocale(LC_ALL, $locale);
    }

    if($self->{_expand})
    {    my $re   = join '|', map quotemeta, keys %$self;
         $text    =~ s/\{($re)(\%[^}]*)?\}/$self->_expand($1,$2)/ge;
    }

    $text  = "$self->{_prepend}$text"
        if defined $self->{_prepend};

    $text .= "$self->{_append}"
        if defined $self->{_append};

    setlocale(LC_ALL, $oldloc)
        if defined $oldloc && $oldloc ne $locale;

    $text;
}

sub _expand($$)
{   my ($self, $key, $format) = @_;
    my $value = $self->{$key};

    $value = $value->($self)
        while ref $value eq 'CODE';

    defined $value
        or return "undef";

    use locale;
    if(ref $value eq 'ARRAY')
    {   my @values = map {defined $_ ? $_ : 'undef'} @$value;
        @values or return '(none)';
        return $format
             ? join($self->{_join}, map sprintf($format, $_), @values)
             : join($self->{_join}, @values);
    }

      $format
    ? sprintf($format, $value)
    : "$value";   # enforce stringification on objects
}

=method untranslated
Return the concatenation of the prepend, msgid, and append strings.  Variable
expansions within the msgid is not performed.
=cut

sub untranslated()
{  my $self = shift;
     (defined $self->{_prepend} ? $self->{_prepend} : '')
   . (defined $self->{_msgid}   ? $self->{_msgid}   : '')
   . (defined $self->{_append}  ? $self->{_append}  : '');
}

=method concat STRING|OBJECT, [PREPEND]
This method implements the overloading of concatenation, which is needed
to delay translations even longer.  When PREPEND is true, the STRING
or OBJECT (other C<Log::Report::Message>) needs to prepended, otherwise
it is appended.

=examples of concatenation
 print __"Hello" . ' ' . __"World!";
 print __("Hello")->concat(' ')->concat(__"World!")->concat("\n");

=cut

sub concat($;$)
{   my ($self, $what, $reversed) = @_;
    if($reversed)
    {   $what .= $self->{_prepend} if defined $self->{_prepend};
        return ref($self)->new(%$self, _prepend => $what);
    }

    $what = $self->{_append} . $what if defined $self->{_append};
    ref($self)->new(%$self, _append => $what);
}

=chapter DETAILS

=section OPTIONS and VARIABLES
The M<Log::Report> functions which define translation request can all
have OPTIONS.  Some can have VARIABLES to be interpolated in the string as
well.  To distinguish between the OPTIONS and VARIABLES (both a list
of key-value pairs), the keys of the OPTIONS start with an underscore C<_>.
As result of this, please avoid the use of keys which start with an
underscore in variable names.  On the other hand, you are allowed to
interpolate OPTION values in your strings.

=subsection Interpolating
With the C<__x()> or C<__nx()>, interpolation will take place on the
translated MSGID string.  The translation can contain the VARIABLE
and OPTION names between curly brackets.  Text between curly brackets
which is not a known parameter will be left untouched.

 fault __x"cannot open open {filename}", filename => $fn;

 print __xn"directory {dir} contains one file"
          ,"directory {dir} contains {nr_files} files"
          , scalar(@files)            # (1) (2)
          , nr_files => scalar @files # (3)
          , dir      => $dir;

(1) this required third parameter is used to switch between the different
plural forms.  English has only two forms, but some languages have many
more.

(2) the "scalar" keyword is not needed, because the third parameter is
in SCALAR context.  You may also pass C< \@files > there, because ARRAYs
will be converted into their length.  A HASH will be converted into the
number of keys in the HASH.

(3) the C<scalar> keyword is required here, because it is LIST context:
otherwise all filenames will be filled-in as parameters to C<__xn()>.
See below for the available C<_count> valure, to see how the C<nr_files>
parameter can disappear.

=subsection Interpolation of VARIABLES

There is no way of checking beforehand whether you have provided all required
values, to be interpolated in the translated string.

For interpolating, the following rules apply:
=over 4
=item *
Simple scalar values are interpolated "as is"
=item *
References to SCALARs will collect the value on the moment that the
output is made.  The C<Log::Report::Message> object which is created with
the C<__xn> can be seen as a closure.  The translation can be reused.
See example below.
=item *
Code references can be used to create the data "under fly".  The
C<Log::Report::Message> object which is being handled is passed as
only argument.  This is a hash in which all OPTIONS and VARIABLES
can be found.
=item *
When the value is an ARRAY, all members will be interpolated with C<$">
between the elements.  Alternatively (maybe nicer), you can pass an
interpolation parameter via the C<_join> OPTION.
=back

 local $" = ', ';
 error __x"matching files: {files}", files => \@files;

 error __x"matching files: {files}", files => \@files, _join => ', ';

=subsection Interpolating formatted

Next to the name, you can specify a format code.  With C<gettext()>,
you often see this:

 printf gettext("approx pi: %.6f\n"), PI;

M<Locale::TextDomain> has two ways.

 printf __"approx pi: %.6f\n", PI;
 print __x"approx pi: {approx}\n", approx => sprintf("%.6f", PI);

The first does not respect the wish to be able to reorder the
arguments during translation.  The second version is quite long.
With C<Log::Report>, above syntaxes do work, but you can also do

 print __x"approx pi: {pi%.6f}\n", pi => PI;

So: the interpolation syntax is C< { name [format] } >.  Other
examples:

 print __x "{perms} {links%2d} {user%-8s} {size%10d} {fn}\n"
         , perms => '-rw-r--r--', links => 1, user => 'me'
         , size => '12345', fn => $filename;

An additional advantage is the fact that not all languages produce
comparable length strings.  Now, the translators can take care that
the layout of tables is optimal.

=subsection Interpolation of OPTIONS

You are permitted the interpolate OPTION values in your string.  This may
simplify your coding.  The useful names are:

=over 4
=item _msgid
The MSGID as provided with M<Log::Report::__()> and M<Log::Report::__x()>

=item _plural, _count
The PLURAL MSGIDs, respectively the COUNT as used with
M<Log::Report::__n()> and M<Log::Report::__nx()>

=item _textdomain
The label of the textdomain in which the translation takes place.

=item _class or _classes
Are to be used to group reports, and can be queried with M<inClass()>,
M<Log::Report::Exception::inClass()>, or
M<Log::Report::Dispatcher::Try::wasFatal()>.
=back

=example using the _count
With M<Locale::TextDomain>, you have to do

  use Locale::TextDomain;
  print __nx ( "One file has been deleted.\n"
             , "{num} files have been deleted.\n"
             , $num_files
             , num => $num_files
             );

With C<Log::Report>, you can do

  use Log::Report;
  print __nx ( "One file has been deleted.\n"
             , "{_count} files have been deleted.\n"
             , $num_files
             );

Of course, you need to be aware that the name used to reference the
counter is fixed to C<_count>.  The first example works as well, but
is more verbose.

=subsection Handling white-spaces

In above examples, the msgid and plural form have a trailing new-line.
In general, it is much easier to write

   print __x"Hello, World!\n";

than

   print __x("Hello, World!") . "\n";

For the translation tables, however, that trailing new-line is "over
information"; it is an layout issue, not a translation issue.

Therefore, the first form will automatically be translated into the
second.  All leading and trailing white-space (blanks, new-lines, tabs,
...) are removed from the msgid befor the look-up, and then added to
the translated string.

Leading and trailing white-space on the plural form will also be
removed.  However, after translation the spacing of the msgid will
be used.

=subsection Avoiding repetative translations

This way of translating is somewhat expensive, because an object to
handle the C<__x()> is created each time.

 for my $i (1..100_000)
 {   print __x "Hello World {i}\n", i => $i;
 }

The suggestion that M<Locale::TextDomain> makes to improve performance,
is to get the translation outside the loop, which only works without
interpolation:

 use Locale::TextDomain;
 my $i = 42;
 my $s = __x("Hello World {i}\n", i => $i);
 foreach $i (1..100_000)
 {   print $s;
 }

Oops, not what you mean.
With Log::Report, you can do it.

 use Log::Report;
 my $i;
 my $s = __x("Hello World {i}\n", i => \$i);
 foreach $i (1..100_000)
 {   print $s;
 }

Mind you not to write: C<for my $i> in above case!!!!

You can also write an incomplete translation:

 use Log::Report;
 my $s = __x "Hello World {i}\n";
 foreach my $i (1..100_000)
 {   print $s->(i => $i);
 }

In either case, the translation will be looked-up only once.
=cut

1;
