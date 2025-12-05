#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Message;

use warnings;
use strict;

use Log::Report       'log-report', import => [ qw/textdomain/ ];

use POSIX             qw/locale_h/;
use List::Util        qw/first/;
use Scalar::Util      qw/blessed/;

use Log::Report::Util qw/to_html/;

# Work-around for missing LC_MESSAGES on old Perls and Windows
{	no warnings;
	eval "&LC_MESSAGES";
	*LC_MESSAGES = sub(){5} if $@;
}

#--------------------
=chapter NAME

Log::Report::Message - a piece of text to be translated

=chapter SYNOPSIS

  # Objects created by Log::Report's __ functions
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
Any use of a constructor function exported by Log::Report, like
C<__()> (the function is named underscore-underscore) or C<__x()>
(underscore-underscore-x) will result in this Message object.  It will capture
some environmental information as well.

The optional translation is delayed until it is really needed.
Creating an object first and translating it later, might be slower than
translating it immediately.  However (by design decissions of Log::Report)
on the location where the message is produced, we do not yet know in
what language to translate it to: that depends on the actual log dispatcher
configurations in the main program.

=chapter OVERLOADED

=overload "" stringification
When the object is used in string context, it will get translated.
Implemented as M<toString()>.

=overload &() used as function
When the object is called as function, a new object is created with
the data from the original one but updated with the new parameters.
Implemented in C<clone()>.

=overload . concatenation
An (accidental) use of concatenation (a dot where a comma should be
used) would immediately stringify the object.  This is avoided by
overloading that operation.
=cut

use overload
	'""'  => 'toString',
	'&{}' => sub { my $obj = shift; sub{$obj->clone(@_)} },
	'.'   => 'concat',
	fallback => 1;

#--------------------
=chapter METHODS

=section Constructors

=c_method new %options
B<End-users: do not use this method directly>, but use
M<Log::Report::__()>, M<Log::Report::__x()> and friends.  The %options
is a mixed list of object initiation parameters (all with a leading
underscore) and variables to be filled in into the translated P<_msgid>
string.

=option  _expand BOOLEAN
=default _expand false
Indicates whether variables are to be filled-in; whether C<__x> or C<__> was
used to define the message.

=option  _domain $name|$object
=default _domain <from "use Log::Report">
The text-domain (translation table) to which this P<_msgid> belongs.

With this parameter, your can "borrow" translations from other textdomains.
Be very careful with this (although there are good use-cases)  The xgettext
msgid extractor may add the used msgid to this namespace as well.  To
avoid that, add a harmless '+':

  print __x(+"errors", _domain => 'global');

The extractor will not take the msgid when it is an expression.  The '+'
has no effect on the string at runtime.

=option  _count INTEGER|ARRAY|HASH
=default _count undef
When defined, the P<_plural> need to be defined as well.  When an
ARRAY is provided, the length of the ARRAY is taken.  When a HASH
is given, the number of keys in the HASH is used.

=option  _plural $msgid
=default _plural undef
Can be used together with P<_count>.  This plural form of the P<_msgid>
text is used to simplify the work of translators, and as fallback when
no translation is possible: therefore, this can best resemble an
English message.

White-space at the beginning and end of the string are stripped off.
The white-space provided by the P<_msgid> will be used.

=option  _msgid $msgid
=default _msgid undef
The message label, which refers to some translation information.
Usually a string which is close the English version of the message.
This will also be used if there is no translation possible/known.

Leading white-space C<\s> will be added to P<_prepend>.  Trailing
white-space will be added before P<_append>.

=option  _category INTEGER
=default _category undef
The category when the real gettext library is used, for instance
LC_MESSAGES.

=option  _prepend $text|$message
=default _prepend undef
Some $text or other $message object which need to be glued before this
message object.

=option  _append  $text|$message
=default _append  undef
Some $text or other $message object which need to be pasted after this
message object.

=option  _tag   $tags|\@tags
=default _tag   []
When messages are used for exception based programming, you add a
P<_tag> parameter to the argument list.  Later, with for instance
M<Log::Report::Dispatcher::Try::wasFatal(tag)>, you can check the
category (group, class) of the exception.

The $tags is interpreted as comma- and/or blank separated list of class
tokens (barewords), the ARRAY lists all tags separately. See M<tags()>.

=option  _tags $tags|\@tags
=default _tags []
Alternative name for P<_tag>

=option  _classes $tags|\@tags
=default _classes undef
Deprecated alternative for P<_tag>.

=option  _class   $tags|\@tags
=default _class   undef
Deprecated alternative for P<_tag>.

=option  _to $dispatcher
=default _to undef
Specify the $dispatcher as destination explicitly. Short
for  C<< report {to => NAME}, ... >>  See M<to()>

=option  _join $separator
=default _join C<$">  C<$LIST_SEPARATOR>
Which $separator string to be used then an ARRAY is being filled-in.

=option  _lang ISO
=default _lang <from locale>
[1.00] Override language setting from locale, for instance because that
is not configured correctly (yet).  This does not extend to prepended
or appended translated message object.

=option  _context $keyword|\@keywords
=default _context undef
[1.00] Set the @keywords which can be used to select alternatives
between translations.  Read the DETAILS section in
Log::Report::Translator::Context

=option  _msgctxt $context
=default _msgctxt undef
[1.22] Message $context in the translation file, the traditional use.  Cannot
be combined with P<_context> on the same msgids.
=cut

sub new($@)
{	my ($class, %s) = @_;

	if(ref $s{_count})
	{	my $c        = $s{_count};
		$s{_count}   = ref $c eq 'ARRAY' ? @$c : keys %$c;
	}

	defined $s{_join}
		or $s{_join} = $";

	if($s{_msgid})
	{	$s{_append}  = defined $s{_append} ? $1.$s{_append} : $1
			if $s{_msgid} =~ s/(\s+)$//s;

		$s{_prepend}.= $1
			if $s{_msgid} =~ s/^(\s+)//s;
	}
	if($s{_plural})
	{	s/\s+$//, s/^\s+// for $s{_plural};
	}

	my $tags  = delete $s{_tag} // delete $s{_tags} // delete $s{_class} // delete $s{_classes} // [];
	$s{_tags} = ref $tags eq 'ARRAY' ? $tags : [ split /[,\s]+/, $tags ];

	bless \%s, $class;
}

# internal use only: to simplify __*p* functions
sub _msgctxt($) {$_[0]->{_msgctxt} = $_[1]; $_[0]}

=method clone %options, $variables
Returns a new object which copies info from original, and updates it
with the specified %options and $variables.  The advantage is that the
cached translations are shared between the objects.

=examples use of clone()
  my $s = __x "found {nr} files", nr => 5;
  my $t = $s->clone(nr => 3);
  my $t = $s->(nr => 3);      # equivalent
  print $s;     # found 5 files
  print $t;     # found 3 files
=cut

sub clone(@)
{	my $self = shift;
	(ref $self)->new(%$self, @_);
}

#--------------------
=section Accessors

=method prepend
Returns the string which is prepended to this one.  Usually undef.

=method msgid
Returns the msgid which will later be translated.

=method append
Returns the string or Log::Report::Message object which is appended
after this one.  Usually undef.

=method domain
Returns the domain of the first translatable string in the structure.

=method count
Returns the count, which is used to select the translation
alternatives.

=method context
Returns an HASH if there is a context defined for this message.

=method msgctxt
The message context for the translation table lookup.
=cut

sub prepend() { $_[0]->{_prepend}}
sub msgid()   { $_[0]->{_msgid}  }
sub append()  { $_[0]->{_append} }
sub domain()  { $_[0]->{_domain} }
sub count()   { $_[0]->{_count}  }
sub context() { $_[0]->{_context}}
sub msgctxt() { $_[0]->{_msgctxt}}

=method tags
Returns the LIST of tags which are defined for this message; message
group indicators, as often found in exception-based programming.

=method classes
Deprecated alternative for M<tags()>.
=cut

sub tags() { @{$_[0]->{_tags}} }
*classes = \&tags;

=method to [$name]
Returns the $name of a dispatcher if explicitly specified with
the '_to' key. Can also be used to set it.  Usually, this will
return undef, because usually all dispatchers get all messages.
=cut

sub to(;$)
{	my $self = shift;
	@_ ? $self->{_to} = shift : $self->{_to};
}

=method errno [$errno]
[1.38] Returns the value of the C<_errno> key, to indicate the error
number (to be returned from your script).  Usually, this method will
return undef.  For FAILURE, FAULT, and ALERT, the errno is by default
taken from C<$!> and C<$?>.
=cut

sub errno(;$)
{	my $self = shift;
	@_ ? $self->{_errno} = shift : $self->{_errno};
}

=method valueOf $parameter
Lookup the named $parameter for the message.  All pre-defined names
have their own method which should be used with preference.

=example
When the message was produced with

  my @files = qw/one two three/;
  my $msg = __xn
     "found one file: {file}",
     "found {nrfiles} files: {files}",
     scalar @files,
     file    => $files[0],
     files   => \@files,
     nrfiles => @files+0,  # or scalar(@files)
     _tags   => [ 'IO', 'files' ],
     _join   => ', ';

then the values can be takes from the produced message as

  my $files = $msg->valueOf('files');  # returns ARRAY reference
  print @$files;                 # 3
  my $count = $msg->count;       # 3
  my @tags  = $msg->tags;        # 'IO', 'files'
  if($msg->taggedWith('files'))  # true

Simplified, the above example can also be written as:

  local $" = ', ';  # Perl default
  my $msg  = __xn
     "found one file: {files}",
     "found {_count} files: {files}",
     @files,      # has scalar context
     files   => \@files,
     _tags   => 'IO, files';

=cut

sub valueOf($) { $_[0]->{$_[1]} }

#--------------------
=section Processing

=method taggedWith $tag|Regexp
Returns true if the message carries the specified $tag (string) or
matches the Regexp.  The trueth value is the (first matching) tag.
=cut

sub taggedWith($)
{	my ($self, $match) = @_;
	ref $match eq 'Regexp' ? (first { $_ =~ $$match } $self->tags) : (first { $_ eq $match } $self->tags);
}

=method inClass $tag|Regexp
Deprecated alternative for M<taggedWith()>.
=cut

*inClass = \&taggedWith;

=method toString [$locale]
Translate a message.  If not specified, the default locale is used.
=cut

sub toString(;$)
{	my ($self, $locale) = @_;

	my $count   = $self->{_count} || 0;
	$locale     = $self->{_lang} if $self->{_lang};
	my $prepend = $self->{_prepend} // '';
	my $append  = $self->{_append}  // '';

	$prepend = $prepend->isa(__PACKAGE__) ? $prepend->toString($locale) : "$prepend"
		if blessed $prepend;

	$append  = $append->isa(__PACKAGE__)  ? $append->toString($locale)  : "$append"
		if blessed $append;

	$self->{_msgid}   # no translation, constant string
		or return "$prepend$append";

	# assumed is that switching locales is expensive
	my $oldloc = setlocale(LC_MESSAGES);
	setlocale(LC_MESSAGES, $locale)
		if defined $locale && (!defined $oldloc || $locale ne $oldloc);

	# translate the msgid
	my $domain = $self->{_domain};
	blessed $domain && $domain->isa('Log::Report::Minimal::Domain')
		or $domain = $self->{_domain} = textdomain $domain;

	my $format = $domain->translate($self, $locale || $oldloc)
		// return ();

	# fill-in the fields
	my $text = $self->{_expand} ? $domain->interpolate($format, $self) : "$prepend$format$append";

	setlocale(LC_MESSAGES, $oldloc)
		if defined $oldloc && (!defined $locale || $oldloc ne $locale);

	$text;
}


=method toHTML [$locale]
[1.11] Translate the message, and then entity encode HTML volatile characters.

[1.20] When used in combination with a templating system, you may want to
use C<<content_for => 'HTML'>> in M<Log::Report::Domain::configure(formatter)>.

=example

  print $msg->toHTML('NL');

=cut

my %tohtml = qw/  > gt   < lt   " quot  & amp /;

sub toHTML(;$) { to_html($_[0]->toString($_[1])) }

=method untranslated
Return the concatenation of the prepend, msgid, and append strings.  Variable
expansions within the msgid is not performed.
=cut

sub untranslated()
{	my $self = shift;
	($self->{_prepend} // '') . ($self->{_msgid} // '') . ($self->{_append} // '');
}

=method concat STRING|$object, [$prepend]
This method implements the overloading of concatenation, which is needed
to delay translations even longer.  When $prepend is true, the STRING
or $object (other C<Log::Report::Message>) needs to prepended, otherwise
it is appended.

=examples of concatenation
  print __"Hello" . ' ' . __"World!\n";
  print __("Hello")->concat(' ')->concat(__"World!")->concat("\n");

=cut

sub concat($;$)
{	my ($self, $what, $reversed) = @_;
	if($reversed)
	{	$what .= $self->{_prepend} if defined $self->{_prepend};
		return (ref $self)->new(%$self, _prepend => $what);
	}

	$what = $self->{_append} . $what if defined $self->{_append};
	(ref $self)->new(%$self, _append => $what);
}

#--------------------
=chapter DETAILS

=section OPTIONS and VARIABLES

The Log::Report functions which define translation request can all
have OPTIONS.  Some can have VARIABLES to be interpolated in the string as
well.  To distinguish between the OPTIONS and VARIABLES (both a list
of key-value pairs), the keys of the OPTIONS start with an underscore C<_>.
As result of this, please avoid the use of keys which start with an
underscore in variable names.  On the other hand, you are allowed to
interpolate OPTION values in your strings.

With the C<__x()> or C<__nx()>, interpolation will take place on the
translated MSGID string.  The translation can contain the VARIABLE
and OPTION names between curly brackets.  Text between curly brackets
which is not a known parameter will be left untouched.

=section Why use format strings?

Simple perl scripts will use C<print()> with variables in the string.
However, when the content of the variable gets more unpredictable or
needs some pre-processing, then it gets tricky.  When you do want to
introduce translations (in the far future of your successful project)
it gets impossible.  Let me give you some examples:

  print "product: $name\n";    # simple perl

  # Will not work because "$name" is interpolated too early
  print translate("product: $name"), "\n";

  # This is the gettext solution, with formats
  printf translate("product: %s\n"), $name;

  # With named in stead of positional parameters
  print translate("product: {p}\n", p => $name);

  # With Log::Report, the translate() is hidden in __x()
  print __x"product: {p}\n", p => $name;

Besides making translation possible, interpolation via format strings
is much cleaner than in the simpelest perl way.  For instance, these
cases:

  # Safety measures while interpolation
  my $name = undef;
  print "product: $name\n";   # uninitialized warning
  print __x"product: {p}\n", p => $name;  # --> product: undef

  # Interpolation of more complex data
  my @names = qw/a b c/;
  print "products: ", join(', ', @names), "\n";
  print __x"products: {p}\n", p => \@names;

  # Padded values hard to do without format strings
  print "padded counter: ", ' ' x (6-length $c), "$c\n";
  printf "padded counter: %6d\n", $counter;
  print __x"padded counter: {c%6d}\n", c => $counter;

So: using formats has many advantages.  Advice: use simple perl only in
trace and assert messages, maybe also with panics.  For serious output
of your program, use formatted output.

=section Messages with plural forms

The M<Log::Report::__xn()> message constructor is used when you need
a different translation based on the count of one of the inserted
fields.

  fault __x"cannot read {file}", file => $fn;
  # --> FAULT: cannot read /etc/shadow: Permission denied\n

  print __xn"directory {dir} contains one file",
            "directory {dir} contains {nr_files} files",
            scalar(@files),            # (1) (2) (3)
            nr_files => scalar @files, # (4)
            dir      => $dir;

(1) this required third parameter is used to switch between the different
plural forms.  English has only two forms, but some languages have many
more.

(2) the "scalar" keyword is not needed, because the third parameter is
in SCALAR context.  You may also pass C< \@files > there, because ARRAYs
will be converted into their length.  A HASH will be converted into the
number of keys in the HASH.

(3) you could also simply pass a reference to the ARRAY: it will take
the length as counter.  With a HASH, it will count the number of keys.

(4) the C<scalar> keyword is required here, because it is LIST context:
otherwise all filenames will be filled-in as parameters to C<__xn()>.
See below for the available C<_count> value, to see how the C<nr_files>
parameter can disappear.

  print __xn"directory {dir} contains one file",
            "directory {dir} contains {_count} files",
            \@files, dir => $dir;

Some languages need more than two translations based on the counter.
This is solved by the translation table definition.  The two msgids
give here are simply the fallback, when there is not translation table
active.

=subsection Interpolation with String::Print

There is no way of checking beforehand whether you have provided all
required values, to be interpolated in the translated string.

This Log::Report::Message uses String::Print to handle formatted strings.
On object of that module is hidden in the logic of M<__x()> and friends.

String::Print is a very capable format string processor, and you should
really B<read its manual> page to see how it can help you.  It would be
possible to support an other formatter (pretty simple even), but this is
not (yet) supported.

=examples using format features

  # This tries to display the $param as useful and safe as possible,
  # where you have totally no idea what its contents is.
  error __x"illegal parameter {p UNKNOWN}.", p => $param;
  # ---> "illegal parameter 'accidentally passed text'."
  # ---> "illegal parameter Unexpected::Object::Type."

  # fault() adds ": $!", with $! translated when configured.
  open my($fh), "<:encoding(utf-8)", $filename
  	 or fault __x"cannot read {file}", file => $filename;

  # Auto-abbreviation
  trace __x"first lines: '{text EL}'\n", text => $t;
  # ---> "first lines: 'This text is long, we sho⋯'.\n"

  trace __x"first lines: {text CHOP}\n", text => $t;
  # ---> "This text is long, we [+3712 chars]\n"

  info __x"file {file} size {size BYTES}\n", file => $fn, size => -s $fn;
  # --> "/etc/passwd size 23kB\n"

  # HASH or object values
  print __x"Name: {user.first} {user.surname}\n", user => $login;

There are more nice standard interpolation modifiers, and you can add
your own.  Besides, you can add serializers which determine how
objects are inlined.

=section Automatic parameters

Besides the parameters which you specify yourself, Log::Report will add
a few which can also be interpolated.  The all start with an underscore
(C<_>).  These are collected when this Message object is instantiated,
see the C<%options> of M<new()>.  These parameters have a purpose, but
you are also permitted tp interpolate them in your message.  This may
simplify your coding.

The useful names are:

=over 4
=item _msgid
The MSGID as provided with M<Log::Report::__()> and M<Log::Report::__x()>

=item _plural, _count
The plural (second) msgid, respectively the counter value as used with
M<Log::Report::__n()> and M<Log::Report::__nx()>

=item _textdomain
The label of the textdomain in which the translation takes place.

=item _join
The string which is used between elements of an ARRAY, when it gets
interpolated in a single field.

=item _tags
[1.44] Tags are to be used to group exceptions, and can be queried with M<taggedWith()>,
M<Log::Report::Exception::taggedWith()>, or
M<Log::Report::Dispatcher::Try::wasFatal(tag)>.

=back

=example using the _count
With Locale::TextDomain, you have to do

  use Locale::TextDomain;
  print __nx(
     "One file has been deleted.\n",
     "{num} files have been deleted.\n",
     $num_files,
     num => $num_files,
  );

With C<Log::Report>, you can do

  use Log::Report;
  print __nx(
     "One file has been deleted.\n",
     "{_count} files have been deleted.\n",
     $num_files,
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

For the translation tables, however, that trailing new-line is "ignorable
information"; it is an layout issue, not a translation issue.

Therefore, the first form will automatically be translated into the
second.  All leading and trailing white-space (blanks, new-lines, tabs,
...) are removed from the msgid before the look-up, and then added to
the translated string.

Leading and trailing white-space on the plural form will also be
removed.  However, after translation the spacing of the msgid will
be used.

=subsection Avoiding repetative translations

This way of translating is somewhat expensive, because an object to
handle the C<Log::Report::__x()> is created each time.

  for my $i (1..100_000)
  {   print __x "Hello World {i}\n", i => $i;
  }

The suggestion that Locale::TextDomain makes to improve performance,
is to get the translation outside the loop, which only works without
interpolation:

  use Locale::TextDomain;
  my $i = 42;
  my $s = __x("Hello World {i}\n", i => $i);
  foreach $i (1..100_000)
  {   print $s;
  }

B<Oops,> not what you mean because the first value of C<$i> is captured
in the initial message object.  With Log::Report, you can do it (except
when you use contexts)

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
