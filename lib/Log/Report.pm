# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Log::Report;
use base 'Exporter';

use warnings;
use strict;

use List::Util         qw/first/;
use Scalar::Util       qw/blessed/;

use Log::Report::Util;
my $lrm = 'Log::Report::Message';

### if you change anything here, you also have to change Log::Report::Minimal
my @make_msg   = qw/__ __x __n __nx __xn N__ N__n N__w __p __px __np __npx/;
my @functions  = qw/report dispatcher try textdomain/;
my @reason_functions = qw/trace assert info notice warning
   mistake error fault alert failure panic/;

our @EXPORT_OK = (@make_msg, @functions, @reason_functions);

sub _whats_needed(); sub dispatcher($@); sub textdomain(@);
sub trace(@); sub assert(@); sub info(@); sub notice(@); sub warning(@);
sub mistake(@); sub error(@); sub fault(@); sub alert(@); sub failure(@);
sub panic(@);
sub __($); sub __x($@); sub __n($$$@); sub __nx($$$@); sub __xn($$$@);
sub N__($); sub N__n($$); sub N__w(@);
sub __p($$); sub __px($$@); sub __np($$$$); sub __npx($$$$@);

#
# Some initiations
#

my $reporter     = {};
my $default_mode = 0;
my @nested_tries;

# we can only load these after Log::Report has compiled, because
# they use this module themselves as well.

require Log::Report::Die;
require Log::Report::Domain;
require Log::Report::Message;
require Log::Report::Exception;
require Log::Report::Dispatcher;
require Log::Report::Dispatcher::Try;

textdomain 'log-report';

my $default_dispatcher = dispatcher PERL => 'default', accept => 'NOTICE-';

=chapter NAME
Log::Report - report a problem, with exceptions and translation support

=chapter SYNOPSIS
 # Invocation with 'mode' to get trace and verbose messages
 use Log::Report mode => 'DEBUG';

 # Usually invoked with a domain, which groups packages for translation
 use Log::Report 'my-domain', %options;

 # Interpolation syntax via String::Print
 # First step to translations, once you need it.
 print __x"my name is {name}", name => $n;  # print, so no exception
 print __"Hello World\n";     # no interpolation, optional translation
 print __x'Hello World';      # SYNTAX ERROR!!  ' is alternative for ::

 # Functions replacing die/warn/carp, casting exceptions.
 error "oops";                # exception like die(), no translation
 -f $config or panic "Help!"; # alert/error/fault/info/...more

 # Combined exception, interpolation, and optional translation
 error __x"Help!";            # __x() creates ::Message object
 error __x('gettext msgid', param => $value, ...)
     if $condition;

 # Also non fatal "exceptions" find their way to dispatchers
 info __x"started {pid}", pid => $$;   # translatable
 debug "$i was here!";        # you probably do not want to translate debug
 panic "arrghhh";             # like Carp::Confess

 # Many destinations for an exception message (may exist in parallel)
 dispatcher PERL => 'default' # see Log::Report::Dispatcher: use die/warn
   , reasons => 'NOTICE-';    # this dispatcher is already present at start

 dispatcher SYSLOG => 'syslog'# also send to syslog
   , charset => 'iso-8859-1'  # explicit character conversions
   , locale => 'en_US';       # overrule user's locale

 dispatcher close => 'default';  # stop default die/warn dispatcher

 # Fill-in values, like Locale::TextDomain and gettext
 # See Log::Report::Message section DETAILS
 fault __x"cannot allocate {size} bytes", size => $size;
 fault "cannot allocate $size bytes";     # no translation, ok
 fault __x"cannot allocate $size bytes";  # not translatable, wrong

 # Translation depending on count
 # Leading and trailing whitespace stay magically outside translation
 # tables.  @files in scalar context.  Special parameter with _
 print __xn"found one file\n", "found {_count} files", @files;

 # Borrow from an other text-domain (see M<Log::Report::Message>)
 print __x(+"errors in {line}", _domain => 'global', line => $line);

 # catch errors (implements hidden eval/die)
 try { error };
 if($@) {...}      # $@ isa Log::Report::Dispatcher::Try
 if(my $exception = $@->wasFatal)         # ::Exception object

 # Language translations at the output component
 # Translation management via Log::Report::Lexicon
 use POSIX::1003::Locale qw/setlocale LC_ALL/;
 setlocale(LC_ALL, 'nl_NL');
 info __"Hello World!";      # in Dutch, if translation table found

 # Exception classes, see Log::Report::Exception
 try { error __x"something", _class => 'parsing,schema' };
 if($@->wasFatal->inClass('parsing')) ...

=chapter DESCRIPTION 
Get messages to users and logs.  C<Log::Report> combines three tasks
which are closely related in one:
=over 4
=item . logging (like L<Log::Log4Perl> and syslog), and
=item . exceptions (like error and info), with
=item . translations (like C<gettext> and L<Locale::TextDomain>)
=back
You B<do not need> to use this module for all three reasons: pick what
you need now, maybe extend the usage later.  Read more about how and
why in the L</DETAILS> section, below.  Especially, you should B<read
about the REASON parameter>.

Also, you can study this module swiftly via the article published in
the German Perl C<$foo-magazine>.  English version:
F<http://perl.overmeer.net/log-report/papers/201306-PerlMagazine-article-en.html>

=chapter FUNCTIONS

=section Report Production and Configuration

=function report [%options], $reason, $message|<STRING,$params>, 

The C<report> function is sending (for some $reason) a $message to be
displayed or logged (by a `dispatcher').  This function is the core
for M<error()>, M<info()> etc functions, which are nicer names for this
exception throwing: better use those short names.

The $reason is a string like 'ERROR' (for function C<error()>).
The $message is a M<Log::Report::Message> object (which are created with
the special translation syntax like M<__x()>).  The $message may also
be a plain string, or an M<Log::Report::Exception> object. The optional
first parameter is a HASH which can be used to influence the dispatchers.

The optional %options are listed below.  Quite differently from other
functions and methods, they have to be passed in a HASH as first parameter.

This function returns the LIST of dispatchers which accepted the $message.
When empty, no back-end has accepted it so the $message was "lost".
Even when no back-end needs the message, the program will still exit
when there is a $reason to C<die()>.

=option  to NAME|ARRAY-of-NAMEs
=default to C<undef>
Sent the $message only to the NAMEd dispatchers.  Ignore unknown NAMEs.
Still, the dispatcher needs to be enabled and accept the REASONs.

=option  errno INTEGER
=default errno C<$!> or C<1>
When the $reason includes the error text (See L</Run modes>), you can
overrule the error code kept in C<$!>.  In other cases, the return code
defaults to C<1> (historical UNIX behavior). When the message $reason
(combined with the run-mode) is severe enough to stop the program,
this value as return code of the program.  The use of this option itself
will not trigger an C<die()>.

=option  stack ARRAY
=default stack C<undef>
When defined, that data is used to display the call stack.  Otherwise,
it is collected via C<caller()> if needed.

=option  location STRING
=default location C<undef>
When defined, this location is used in the display.  Otherwise, it
is determined automatically if needed.  An empty string will disable
any attempt to display this line.

=option  locale LOCALE
=default locale C<undef>
Use this specific locale, in stead of the user's preference.

=option  is_fatal BOOLEAN
=default is_fatal <depends on reason>
Some logged exceptions are fatal, other aren't.  The default usually
is correct. However, you may want an error to be caught (usually with
M<try()>), redispatch it to syslog, but without it killing the main
program.

=examples for use of M<report()>
 # long syntax example
 report TRACE => "start processing now";
 report INFO  => '500: ' . __'Internal Server Error';

 # explicit dispatcher, no translation
 report {to => 'syslog'}, NOTICE => "started process $$";
 notice "started process $$", _to => 'syslog';   # same

 # short syntax examples
 trace "start processing now";
 warning  __x'Disk {percent%.2f}% full', percent => $p
     if $p > 97;

 # error message, overruled to be printed in Brazilian
 report {locale => 'pt_BR'}
    , WARNING => "do this at home!";
 
=cut

sub report($@)
{   my $opts = ref $_[0] eq 'HASH' ? +{ %{ (shift) } } : {};
    my ($reason, $message) = (shift, shift);

    my $stop = exists $opts->{is_fatal} ? $opts->{is_fatal} : is_fatal $reason;
    my $try  = $nested_tries[-1];

    my @disp;
    if(defined $try)
    {   push @disp, @{$reporter->{needs}{$reason}||[]}
            unless $stop || $try->hides($reason);
        push @disp, $try if $try->needs($reason);
    }
    else
    {   @disp = @{$reporter->{needs}{$reason} || []};
    }

    is_reason $reason
        or error __x"token '{token}' not recognized as reason", token=>$reason;

    # return when no-one needs it: skip unused trace() fast!
    @disp || $stop
        or return;

    if(my $to = delete $opts->{to})
    {   # explicit destination, still disp may not need it.
        if(ref $to eq 'ARRAY')
        {   my %disp = map +($_->name => $_), @disp;
            @disp    = grep defined, @disp{@$to};
        }
        else
        {   @disp    = grep $_->name eq $to, @disp;
        }
        @disp || $stop
            or return;
    }

    $opts->{errno} ||= $!+0 || $? || 1
        if use_errno($reason) && !defined $opts->{errno};

    unless(Log::Report::Dispatcher->can('collectLocation'))
    {   # internal Log::Report error can result in "deep recursions".
        eval "require Carp"; Carp::confess($message);
    }
    $opts->{location} ||= Log::Report::Dispatcher->collectLocation;

    my $exception;
    if(!blessed $message)
    {   # untranslated message into object
        @_%2 and error __x"odd length parameter list with '{msg}'", msg => $message;
        $message  = $lrm->new(_prepend => $message, @_);
    }
    elsif($message->isa('Log::Report::Exception'))
    {   $exception = $message;
        $message   = $exception->message;
    }
    elsif($message->isa('Log::Report::Message'))
    {   @_==0 or error __x"a message object is reported with more parameters";
    }
    else
    {   # foreign object
        my $text = "$message";  # hope stringification is overloaded
		$text    =~ s/\s*$//gs;
        @_%2 and error __x"odd length parameter list with object '{msg}'",
             msg => $text;
        $message = $lrm->new(_prepend => $text, @_);
    }

    if(my $to = $message->to)
    {   @disp = grep $_->name eq $to, @disp;
        push @disp, $try if $try && $to ne 'try';
        @disp or return;
    }

    my $domain = $message->domain;
    if(my $filters = $reporter->{filters})
    {
      DISPATCHER:
        foreach my $d (@disp)
        {   my ($r, $m) = ($reason, $message);
            foreach my $filter (@$filters)
            {   next if keys %{$filter->[1]} && !$filter->[1]{$d->name};
                ($r, $m) = $filter->[0]->($d, $opts, $r, $m, $domain);
                $r or next DISPATCHER;
            }
            $d->log($opts, $r, $m, $domain);
        }
    }
    else
    {   $_->log($opts, $reason, $message, $domain) for @disp;
    }

    if($stop)
    {   # $^S = $EXCEPTIONS_BEING_CAUGHT; parse: undef, eval: 1, else 0
        (defined($^S) ? $^S : 1) or exit($opts->{errno} || 0);

        $! = $opts->{errno} || 0;
        $@ = $exception || Log::Report::Exception->new(report_opts => $opts
          , reason => $reason, message => $message);
        die;   # $@->PROPAGATE() will be called, some eval will catch this
    }

    @disp;
}

=function dispatcher <$type, $name, %options>|<$command, @names>

The C<dispatcher> function controls access to dispatchers: the back-ends
which process messages, do the logging.  Dispatchers are global entities,
addressed by a symbolic $name.  Please read M<Log::Report::Dispatcher> as
well.

The C<Log::Report> suite has its own dispatcher @types, but also connects
to external dispatching frameworks.  Each need some (minor) conversions,
especially with respect to translation of REASONS of the reports
into log-levels as the back-end understands.

[1.10] When you open a dispatcher with a $name which is already in use,
that existing dispatcher gets closed.  Except when you have given an
'dispatcher "do-not-reopen"' earlier, in which case the first object
stays alive, and the second attempt ignored. [1.11] The automatically
created default dispatcher will get replaced, even when this option
is given, by another dispatcher which is named 'default'.

The %options are a mixture of parameters needed for the
Log::Report dispatcher wrapper and the settings of the back-end.
See M<Log::Report::Dispatcher>, the documentation for the back-end
specific wrappers, and the back-ends for more details.

Implemented COMMANDs are C<close>, C<find>, C<list>, C<disable>,
C<enable>, C<mode>, C<filter>, C<needs>, C<active-try>, and C<do-not-reopen>.

Most commands are followed by a LIST of dispatcher @names to be addressed.
For C<mode> see section L</Run modes>; it requires a MODE argument
before the LIST of NAMEs.  Non-existing names will be ignored. When
C<ALL> is specified, then all existing dispatchers will get addressed.
For C<filter> see L<Log::Report::Dispatcher/Filters>; it requires a CODE
reference before the @names of the dispatchers which will have the it
applied (defaults to all).

With C<needs>, you only provide a REASON: it will return the list of
dispatchers which need to be called in case of a message with the REASON
is triggered.  The C<active-try> [1.09] returns the closest surrounding
exception catcher, a M<Log::Report::Dispatcher::Try> object.

For both the creation as COMMANDs version of this method, all objects
involved are returned as LIST, non-existing ones skipped.  In SCALAR
context with only one name, the one object is returned.

=examples play with dispatchers
 dispatcher Log::Dispatcher::File => mylog =>
   , accept   => 'MISTAKE-'              # for wrapper
   , locale   => 'pt_BR'                 # other language
   , filename => 'logfile';              # for back-end

 dispatcher close => 'mylog';            # cleanup
 my $obj = dispatcher find => 'mylog'; 
 my @obj = dispatcher 'list';
 dispatcher disable => 'syslog';
 dispatcher enable => 'mylog', 'syslog'; # more at a time
 dispatcher mode => 'DEBUG', 'mylog';
 dispatcher mode => 'DEBUG', 'ALL';
 my $catcher = dispatcher 'active-try';
 dispatcher 'do-not-reopen';

 my @need_info = dispatcher needs => 'INFO';
 if(dispatcher needs => 'INFO') ...      # anyone needs INFO

 # Getopt::Long integration: see Log::Report::Dispatcher::mode()
 dispatcher PERL => 'default', mode => 'DEBUG', accept => 'ALL'
     if $debug;

=error in SCALAR context, only one dispatcher name accepted
The M<dispatcher()> method returns the M<Log::Report::Dispatcher>
objects which it has accessed.  When multiple names where given, it
wishes to return a LIST of objects, not the count of them.
=cut

my %disp_actions = map +($_ => 1), qw/
  close find list disable enable mode needs filter active-try do-not-reopen
  /;

my $reopen_disp = 1;

sub dispatcher($@)
{   if(! $disp_actions{$_[0]})
    {   my ($type, $name) = (shift, shift);

        # old dispatcher with same name will be closed in DESTROY
        my $disps = $reporter->{dispatchers};
 
        if(!$reopen_disp)
        {   my $has = first {$_->name eq $name} @$disps;
            if(defined $has && $has ne $default_dispatcher)
            {   my $default = $name eq 'default'
                   ? ' (refreshing configuration instead)' : '';
                trace "not reopening $name$default";
                return $has;
            }
        }

        my @disps = grep $_->name ne $name, @$disps;
        trace "reopening dispatcher $name" if @disps != @$disps;

        my $disp = Log::Report::Dispatcher
           ->new($type, $name, mode => $default_mode, @_);

        push @disps, $disp if $disp;
        $reporter->{dispatchers} = \@disps;

        _whats_needed;
        return $disp ? ($disp) : undef;
    }

    my $command = shift;
    if($command eq 'list')
    {   mistake __"the 'list' sub-command doesn't expect additional parameters"
           if @_;
        my @disp = @{$reporter->{dispatchers}};
        push @disp, $nested_tries[-1] if @nested_tries;
        return @disp;
    }
    if($command eq 'needs')
    {   my $reason = shift || 'undef';
        error __"the 'needs' sub-command parameter '{reason}' is not a reason"
            unless is_reason $reason;
        my $disp = $reporter->{needs}{$reason};
        return $disp ? @$disp : ();
    }
    if($command eq 'filter')
    {   my $code = shift;
        error __"the 'filter' sub-command needs a CODE reference"
            unless ref $code eq 'CODE';
        my %names = map +($_ => 1), @_;
        push @{$reporter->{filters}}, [ $code, \%names ];
        return ();
    }
    if($command eq 'active-try')
    {   return $nested_tries[-1];
    }
    if($command eq 'do-not-reopen')
    {   $reopen_disp = 0;
        return ();
    }

    my $mode     = $command eq 'mode' ? shift : undef;

    my $all_disp = @_==1 && $_[0] eq 'ALL';
    my $disps    = $reporter->{dispatchers};
    my @disps;
    if($all_disp) { @disps = @$disps }
    else
    {   # take the dispatchers in the specified order.  Both lists
        # are small, so O(x²) is small enough
        for my $n (@_) { push @disps, grep $_->name eq $n, @$disps }
    }

    error __"only one dispatcher name accepted in SCALAR context"
        if @disps > 1 && !wantarray && defined wantarray;

    if($command eq 'close')
    {   my %kill = map +($_->name => 1), @disps;
        @$disps  = grep !$kill{$_->name}, @$disps;
        $_->close for @disps;
    }
    elsif($command eq 'enable')  { $_->_disabled(0) for @disps }
    elsif($command eq 'disable') { $_->_disabled(1) for @disps }
    elsif($command eq 'mode')
    {    Log::Report::Dispatcher->defaultMode($mode) if $all_disp;
         $_->_set_mode($mode) for @disps;
    }

    # find does require reinventarization
    _whats_needed if $command ne 'find';

    wantarray ? @disps : $disps[0];
}

END { $_->close for @{$reporter->{dispatchers}} }

# _whats_needed
# Investigate from all dispatchers which reasons will need to be
# passed on. After dispatchers are added, enabled, or disabled,
# this method shall be called to re-investigate the back-ends.

sub _whats_needed()
{   my %needs;
    foreach my $disp (@{$reporter->{dispatchers}})
    {   push @{$needs{$_}}, $disp for $disp->needs;
    }
    $reporter->{needs} = \%needs;
}

=function try CODE, %options

Execute the CODE while blocking all dispatchers as long as it is running.
The exceptions which occur while running the CODE are caught until it
has finished.  When there where no fatal errors, the result of the CODE
execution is returned.

After the CODE was tried, the C<$@> will contain a
M<Log::Report::Dispatcher::Try> object, which contains the collected
messages.

Run-time errors from Perl and die's, croak's and confess's within the
program (which shouldn't appear, but you never know) are collected into an
M<Log::Report::Message> object, using M<Log::Report::Die>.

The %options are passed to the constructor of the try-dispatcher, see
M<Log::Report::Dispatcher::Try::new()>.  For instance, you may like to
add C<< mode => 'DEBUG' >>, or C<< accept => 'ERROR-' >>.

B<Be warned> that the parameter to C<try> is a CODE reference.  This means
that you shall not use a comma after the block when there are %options
specified.  On the other hand, you shall use a semi-colon after the
block if there are no arguments.

B<Be warned> that the {} are interpreted as subroutine, which means that,
for instance, it has its own C<@_>.  The manual-page of M<Try::Tiny>
lists a few more side-effects of this.

=examples
 my $x = try { 3/$x };  # mind the ';' !!
 if($@) {               # signals something went wrong

 if(try {...}) {        # block ended normally, returns bool

 try { ... }            # no comma!!
    mode => 'DEBUG', accept => 'ERROR-';

 try sub { ... },       # with comma, also \&function
    mode => 'DEBUG', accept => 'ALL';

 my $response = try { $ua->request($request) };
 if(my $e = $@->wasFatal) ...

=cut

sub try(&@)
{   my $code = shift;

    @_ % 2
      and report {location => [caller 0]}, PANIC =>
          __x"odd length parameter list for try(): forgot the terminating ';'?";

	unshift @_, mode => 'DEBUG'
        if $reporter->{needs}{TRACE};

    my $disp = Log::Report::Dispatcher::Try->new(TRY => 'try', @_);
    push @nested_tries, $disp;

    # user's __DIE__ handlers would frustrate the exception mechanism
    local $SIG{__DIE__};

    my ($ret, @ret);
    if(!defined wantarray)  { eval { $code->() } } # VOID   context
    elsif(wantarray) { @ret = eval { $code->() } } # LIST   context
    else             { $ret = eval { $code->() } } # SCALAR context

    my $err  = $@;
    pop @nested_tries;

    my $is_exception = blessed $err && $err->isa('Log::Report::Exception');
    if(!$is_exception && $err && !$disp->wasFatal)
    {   # Decode exceptions which do not origin from Log::Report reports
        ($err, my($opts, $reason, $text)) = blessed $err
           ? Log::Report::Die::exception_decode($err)
           : Log::Report::Die::die_decode($err, on_die => $disp->die2reason);

        $disp->log($opts, $reason, __$text);
    }

    $disp->died($err)
        if $is_exception ? $err->isFatal : $err;

    $@ = $disp;

    wantarray ? @ret : $ret;
}

#------------
=section Abbreviations for report()

The following functions are all wrappers for calls to M<report()>,
and available when "syntax is SHORT" (by default, see M<import()>).
You cannot specify additional options to influence the behavior of
C<report()>, which are usually not needed anyway.

=function trace $message
Short for C<< report TRACE => $message >>
=function assert $message
Short for C<< report ASSERT => $message >>
=function info $message
Short for C<< report INFO => $message >>
=function notice $message
Short for C<< report NOTICE => $message >>
=function warning $message
Short for C<< report WARNING => $message >>
=function mistake $message
Short for C<< report MISTAKE => $message >>
=function error $message
Short for C<< report ERROR => $message >>
=function fault $message
Short for C<< report FAULT => $message >>
=function alert $message
Short for C<< report ALERT => $message >>
=function failure $message
Short for C<< report FAILURE => $message >>
=function panic $message
Short for C<< report PANIC => $message >>
=cut

sub trace(@)   {report TRACE   => @_}
sub assert(@)  {report ASSERT  => @_}
sub info(@)    {report INFO    => @_}
sub notice(@)  {report NOTICE  => @_}
sub warning(@) {report WARNING => @_}
sub mistake(@) {report MISTAKE => @_}
sub error(@)   {report ERROR   => @_}
sub fault(@)   {report FAULT   => @_}
sub alert(@)   {report ALERT   => @_}
sub failure(@) {report FAILURE => @_}
sub panic(@)   {report PANIC   => @_}

#-------------
=section Messages (optionally translatable)

Even when you do not support translations (yet) you may want to use
message objects to improve the logging feature. For instance,
you get very powerful interpolation from M<String::Print>.

The language translations are initiate by limited set of functions
which contain B<two under-scores> (C<__>) in their name.  Most
of them return a M<Log::Report::Message> object.

B<Be warned(1)> that -in general- its considered very bad practice to
combine multiple translations into one message: translating may also
affect the order of the translated components. Besides, when the person
which translates only sees smaller parts of the text, his (or her) job
becomes more complex.  So:

 print __"Hello" . ', ' . __"World!";  # works, but to be avoided
 print __"Hello, World!";              # preferred, complete sentence

The the former case, tricks with overloading used by the
M<Log::Report::Message> objects will still make delayed translations
work.

In normal situations, it is not a problem to translate interpolated
values:

 print __"the color is {c}", c => __"red";

B<Be warned(2)> that using C<< __'Hello' >> will produce a syntax error like
"String found where operator expected at .... Can't find string terminator
"'" anywhere before EOF".  The first quote is the cause of the complaint,
but the second generates the error.  In the early days of Perl, the single
quote was used to separate package name from function name, a role which
was later replaced by a double-colon.  So C<< __'Hello' >> gets interpreted
as C<< __::Hello ' >>.  Then, there is a trailing single quote which has
no counterpart.

=function __ $msgid
This function (name is B<two> under-score characters) will cause the $msgid
to be replaced by the translations when doing the actual output.  Returned
is a M<Log::Report::Message> object, which will be used in translation
later.  Translating is invoked when the object gets stringified.  When
you have no translation tables, the $msgid will be shown untranslated.

If you need options for M<Log::Report::Message::new()> then use M<__x()>;
the prototype of this function does not permit parameters: it is a
prefix operator!

=examples how to use __()
 print __"Hello World";      # translated into user's language
 print __'Hello World';      # syntax error!
 print __('Hello World');    # ok, translated
 print __"Hello", " World";  # World not translated

 my $s = __"Hello World";    # creates object, not yet translated
 print ref $s;               # Log::Report::Message
 print $s;                   # ok, translated
 print $s->toString('fr');   # ok, forced into French
=cut


sub __($)
{   my ($cpkg, $fn, $linenr) = caller;
    $lrm->new
      ( _msgid  => shift
      , _domain => pkg2domain($cpkg)
      , _use    => "$fn line $linenr"
      );
} 

=function __x $msgid, PAIRS
Translate the $msgid and then interpolate the VARIABLES in that string.
Of course, translation and interpolation is delayed as long as possible.
Both OPTIONS and VARIABLES are key-value pairs.

The PAIRS are options for M<Log::Report::Message::new()> and variables
to be filled in.
=cut

# label "msgid" added before first argument
sub __x($@)
{   my ($cpkg, $fn, $linenr) = caller;
    @_%2 or error __x"even length parameter list for __x at {where}",
        where => "$fn line $linenr";

    my $msgid = shift;
    $lrm->new
      ( _msgid  => $msgid
      , _expand => 1
      , _domain => pkg2domain($cpkg)
      , _use    => "$fn line $linenr"
      , @_
      );
} 

=function __n $msgid, $plural_msgid, $count, PAIRS
It depends on the value of $count (and the selected language) which
text will be displayed.  When translations can not be performed, then
$msgid will be used when $count is 1, and PLURAL_MSGSID in other cases.
However, some languages have more complex schemes than English.

The PAIRS are options for M<Log::Report::Message::new()> and variables
to be filled in.

=examples how to use __n()
 print __n "one", "more", $a;
 print __n("one", "more", $a), "\n";
 print +(__n "one", "more", $a), "\n";

 # new-lines are ignore at lookup, but printed.
 print __n "one\n", "more\n", $a;

 # count is in scalar context
 # the value is also available as _count
 print __n "found one\n", "found {_count}\n", @r;

 # ARRAYs and HASHes are counted
 print __n "one", "more", \@r;
=cut

sub __n($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    my ($cpkg, $fn, $linenr) = caller;
    $lrm->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _domain => pkg2domain($cpkg)
     , _use    => "$fn line $linenr"
     , @_
     );
}

=function __nx $msgid, $plural_msgid, $count, PAIRS
It depends on the value of $count (and the selected language) which
text will be displayed.  See details in M<__n()>.  After translation,
the VARIABLES will be filled-in.

The PAIRS are options for M<Log::Report::Message::new()> and variables
to be filled in.

=examples how to use __nx()
 print __nx "one file", "{_count} files", $nr_files;
 print __nx "one file", "{_count} files", @files;

 local $" = ', ';
 print __nx "one file: {f}", "{_count} files: {f}", @files, f => \@files;
=cut

sub __nx($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    my ($cpkg, $fn, $linenr) = caller;
    $lrm->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _expand => 1
     , _domain => pkg2domain($cpkg)
     , _use    => "$fn line $linenr"
     , @_
     );
}

=function __xn $single_msgid, $plural_msgid, $count, $paurs
Same as M<__nx()>, because we have no preferred order for 'x' and 'n'.
=cut

sub __xn($$$@)   # repeated for prototype
{   my ($single, $plural, $count) = (shift, shift, shift);
    my ($cpkg, $fn, $linenr) = caller;
    $lrm->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _expand => 1
     , _domain => pkg2domain($cpkg)
     , _use    => "$fn line $linenr"
     , @_
     );
}

=function N__ $msgid
Label to indicate that the string is a text which will be translated
later.  The function itself does nothing.  See also M<N__w()>.

This no-op function is used as label to the xgettext program to build the
translation tables.

=example how to use N__()
 # add three msgids to the translation table
 my @colors = (N__"red", N__"green", N__"blue");
 my @colors = N__w "red green blue";   # same
 print __ $colors[1];                  # translate green

 # using M<__()>, would work as well
 my @colors = (__"red", __"green", __"blue");
 print $colors[1];
 # however: this will always create all M<Log::Report::Message> objects,
 # where maybe only one is used.
=cut

sub N__($) { $_[0] }

=function N__n $single_msgid, $plural_msgid
Label to indicate that the two MSGIDs are related, the first as
single, the seconds as its plural.  Only used to find the text
fragments to be translated.  The function itself does nothing.
=examples how to use M<N__n()>
 my @save = N__n "save file", "save files";
 my @save = (N__n "save file", "save files");
 my @save = N__n("save file", "save files");

 # be warned about SCALARs in prototype!
 print __n @save, $nr_files;  # wrong!
 print __n $save[0], $save[1], @files, %vars;
=cut

sub N__n($$) {@_}

=function N__w STRING
This extension to the M<Locale::TextDomain> syntax, is a combined
C<qw> (list of quoted words) and M<N__()> into a list of translatable
words.

=example of M<N__w()>
  my @colors = (N__"red", N__"green", N__"blue");
  my @colors = N__w"red green blue";  # same
  print __ $colors[1];
=cut

sub N__w(@) {split " ", $_[0]}


#-------------
=subsection Messages with msgctxt

In Log::Report, the message context (mgsctxt in the PO-files --in the
translation tables) can be used in a very powerful way.  Read all about
it in M<Log::Report::Translator::Context>

The msgctxt versions of the tranditional gettext infrastructure are far
less useful for Log::Report, because we can easily work with different
text domains within the same program.  That should avoid most of the
accidental translation conflicts between components of the code.

Just for compatibility with M<Locale::TextDomain> and completeness, the
'p' versions of above methods are supported.  See examples for these
functions in M<Locale::TextDomain>.

B<Warnings:> Functions C<N__p()> and C<N__np()> seem not to be usable in
reality, hence not implemented.  The script xgettext-perl and
M<Log::Report::Extract::PerlPPI> (both in the M<Log::Report::Lexicon>
distribution) do not yet support these functions.

=function __p $msgctxt, $msgid
=function __px $msgctxt, $msgid, PAIRS
=function __np $msgctxt, $msgid, $plural, count
=function __npx $msgctxt, $msgid, $plural, count, PAIRS

=cut

sub __p($$) { __($_[0])->_msgctxt($_[1]) }
sub __px($$@)
{   my ($ctxt, $msgid) = (shift, shift);
    __x($msgid, @_)->_msgctxt($ctxt);
}

sub __np($$$$)
{   my ($ctxt, $msgid, $plural, $count) = @_;
    __n($msgid, $msgid, $plural, $count)->_msgctxt($ctxt);
}

sub __npx($$$$@)
{   my ($ctxt, $msgid, $plural, $count) = splice @_, 0, 4;
    __nx($msgid, $msgid, $plural, $count, @_)->_msgctxt($ctxt);
}

#-------------
=section Configuration

=method import [$level,][$domain,] %options
The import is automatically called when the package is compiled.  For all
packages but one in your distribution, it will only contain the name of
the $domain.

For one package, the import list may additionally contain textdomain
configuration %options.  These %options are used for all packages which
use the same $domain.  These are alternatives:

  # Do not use variables in the %*config!  They are not yet initialized
  # when Log::Report->import is run!!!
  use Log::Report 'my-domain', %config, %domain_config;

  use Log::Report 'my-domain', %config;
  textdomain 'my-domain', %domain_config;   # vars allowed

The latter syntax has major advantages, when the configuration of the
domain is determined at run-time.  It is probably also easier to understand.

See M<Log::Report::Domain::configure()>, for the B<list of %options>
for the domain configuration.  Here, we only list the options which are
related to the normal import behavior.

The export $level is a plus (+) followed by a number, for instance C<+1>,
to indicate to on which caller level we need to work.  This is used
in M<Log::Report::Optional>.  It defaults to '0': my direct caller.

=option  syntax 'REPORT'|'SHORT'|'LONG'
=default syntax 'SHORT'
The SHORT syntax will add the report abbreviations (like function
M<error()>) to your name-space.  Otherwise, each message must be produced
with M<report()>. C<LONG> is an alternative to C<REPORT>: both do not
pollute your namespace with the useful abbrev functions.

=option  mode LEVEL
=default mode 'NORMAL'
This sets the default mode for all created dispatchers.  You can
also selectively change the output mode, like
 dispatcher PERL => 'default', mode => 3

=option  import FUNCTION|ARRAY
=default import C<undef>
[0.998] When not specified, the C<syntax> option determines the list
of functions which are being exported.  With this option, the C<syntax>
option is ignored and only the specified FUNCTION(s) are imported.

=option  message_class CLASS
=default message_class C<Log::Report::Message>
[1.08] Use a more powerful message object class, for instance because
your messages need extra attributes.  The provided CLASS must extend
M<Log::Report::Message>

=examples of import
 use Log::Report mode => 3;     # '3' or 'DEBUG'

 use Log::Report 'my-domain';   # in each package producing messages

 use Log::Report 'my-domain'    # in one package, top of distr
  , mode            => 'VERBOSE'
  , syntax          => 'REPORT' # report ERROR, not error()
  , translator      => Log::Report::Translator::POT->new
     ( lexicon => '/home/mine/locale'  # translation tables
     )
  , native_language => 'nl_NL'; # untranslated msgs are Dutch

 use Log::Report import => 'try';      # or ARRAY of functions

=cut

sub import(@)
{   my $class = shift;

    if($INC{'Log/Report/Minimal.pm'})
    {    my ($pkg, $fn, $line) = caller;   # do not report on LR:: modules
         if(index($pkg, 'Log::Report::') != 0)
         {   # @pkgs empty during release testings of L::R distributions
             my @pkgs = Log::Report::Optional->usedBy;
             die "Log::Report loaded too late in $fn line $line, "
               . "put in $pkg before ", (join ',', @pkgs) if @pkgs;
         }
    }

    my $to_level   = ($_[0] && $_[0] =~ m/^\+\d+$/ ? shift : undef) || 0;
    my $textdomain = @_%2 ? shift : undef;
    my %opts       = @_;

    my ($pkg, $fn, $linenr) = caller $to_level;
    my $domain;

    if(defined $textdomain)
    {   pkg2domain $pkg, $textdomain, $fn, $linenr;
        $domain = textdomain $textdomain;
    }

    ### Log::Report options

    if(exists $opts{mode})
    {   $default_mode = delete $opts{mode} || 0;
        Log::Report::Dispatcher->defaultMode($default_mode);
        dispatcher mode => $default_mode, 'ALL';
    }

    my @export;
    if(my $in = delete $opts{import})
    {   push @export, ref $in eq 'ARRAY' ? @$in : $in;
    }
    else
    {   push @export, @functions, @make_msg;

        my $syntax = delete $opts{syntax} || 'SHORT';
        if($syntax eq 'SHORT')
        {   push @export, @reason_functions
        }
        elsif($syntax ne 'REPORT' && $syntax ne 'LONG')
        {   error __x"syntax flag must be either SHORT or REPORT, not `{flag}' in {fn} line {line}"
              , flag => $syntax, fn => $fn, line => $linenr;
        }
    }

    if(my $msg_class = delete $opts{message_class})
    {   $msg_class->isa($lrm)
            or error __x"message_class {class} does not extend {base}"
                 , base => $lrm, class => $msg_class;
        $lrm = $msg_class;
    }

    $class->export_to_level(1+$to_level, undef, @export);

    ### Log::Report::Domain configuration

    if(!%opts) { }
    elsif($domain)
    {   $domain->configure(%opts, where => [$pkg, $fn, $linenr ]) }
    else
    {   error __x"no domain for configuration options in {fn} line {line}"
          , fn => $fn, line => $linenr;
    }
}

# deprecated, since we have a ::Domain object in 1.00
sub translator($;$$$$)
{   # replaced by (textdomain $domain)->configure

    my ($class, $name) = (shift, shift);
    my $domain = textdomain $name
        or error __x"textdomain `{domain}' for translator not defined"
             , domain => $name;

    @_ or return $domain->translator;

    my ($translator, $pkg, $fn, $line) = @_;
    ($pkg, $fn, $line) = caller    # direct call, not via import
        unless defined $pkg;

    $translator->isa('Log::Report::Translator')
        or error __x"translator must be a {pkg} object for {domain}"
              , pkg => 'Log::Report::Translator', domain => $name;

    $domain->configure(translator => $translator, where => [$pkg, $fn, $line]);
}

=function textdomain <[$name],$config>|<$name, 'DELETE'|'EXISTS'>|$domain
[1.00] Without CONFIGuration, this returns the M<Log::Report::Domain> object
which administers the $domain, by default the domain effective in the scope
of the package.

A very special case is "DELETE", which will remove the domain
configuration. [1.20] "EXISTS" will check for existence: when it exists,
it will be returned, but a domain will not be automagically created.

[1.20] You may also pass a pre-configured domain.
=cut

sub textdomain(@)
{   if(@_==1 && blessed $_[0])
    {   my $domain = shift;
        $domain->isa('Log::Report::Domain') or panic;
        return $reporter->{textdomains}{$domain->name} = $domain;
    }

    if(@_==2)
    {    # used for 'maintenance' and testing
    	return delete $reporter->{textdomains}{$_[0]} if $_[1] eq 'DELETE';
    	return $reporter->{textdomains}{$_[0]} if $_[1] eq 'EXISTS';
    }

    my $name   = (@_%2 ? shift : pkg2domain((caller)[0])) || 'default';
    my $domain = $reporter->{textdomains}{$name}
        ||= Log::Report::Domain->new(name => $name);

    $domain->configure(@_, where => [caller]) if @_;
    $domain;
}

#--------------
=section Reasons

=c_method needs $reason, [$reasons]
Returns true when the reporter needs any of the $reasons, when any of
the active dispatchers is collecting messages in the specified level.
This is useful when the processing of data for the message is relatively
expensive, but for instance only required in debug mode.

=example
  if(Log::Report->needs('TRACE'))
  {   my @args = ...expensive calculation...;
      trace "your options are: @args";
  }
=cut

sub needs(@)
{   my $thing = shift;
    my $self  = ref $thing ? $thing : $reporter;
    first {$self->{needs}{$_}} @_;
}

=chapter DETAILS

=section Introduction

Getting messages to users and logs. The distincting concept of this module,
is that three tasks which are strongly related are merged into one simple
syntax.  The three tasks:

=over 4
=item produce some text on a certain condition,
=item translate it to the proper language, and
=item deliver it in some way to a user.
=back

Text messages in Perl are produced by commands like C<print>, C<die>,
C<warn>, C<carp>, or C<croak>.  But where is that output directed to?
Translations is hard.  There is no clean exception mechanism.

Besides, the C<print>/C<warn>/C<die> together produce only three different
output "levels" with a message.  Think of the variation syslog offers:
more than 7 levels.  Many people manually implement their own tricks to
get additional levels, like verbose and debug flags.  Log::Report offers
that variety.

The (optional) translations use the beautiful syntax defined by
M<Locale::TextDomain>, with some own extensions (of course).  A very
important difference is that translations are delayed till the delivery
step: until a dispatcher actually writes your message into a file, sends
it to syslog, or shows it on the screen.  This means that the pop-up in
the graphical interface of the user may show the text in the language
of the user --say Chinese in utf8--, but at the same time syslog may
write the latin1 English version of the same message.

=section Background ideas

The following ideas are the base of this implementation:

=over 4

=item . simplification
Handling errors and warnings is probably the most labor-intensive
task for a programmer: when programs are written correctly, up-to
three-quarters of the code is related to testing, reporting, and
handling (problem) conditions.  Simplifying the way to create reports,
simplifies programming and maintenance.

=item . multiple dispatchers
It is not the location where the (for instance) error occurs which
determines what will happen with the text, but the main application which
uses the the complaining module has control.  Messages have a reason.
Based on the `reason' classification, they can get ignored, send to one
or multiple dispatchers, like M<Log::Dispatch>, M<Log::Log4perl>,
or UNIX syslog.

=item . delayed translations
The background ideas are that of M<Locale::TextDomain>, based
on C<gettext()>.  However, in the C<Log::Report> infrastructure,
translations are postponed until the text is dispatched to a screen
or log-file; the same report can be sent to syslog in (for instance)
English and to the user interface in Dutch.

=item . context sensitive
Using contexts, you can set-up how to translate or rewrite messages,
to improve messages.  A typical problem is whether to use gender in
text (use 'his' or 'her'): you can set a gender in a context, and the
use translation tables to pick the right one.
=back

=section Error handling models

There are two approaches to handling errors and warnings.  In the first
approach, as produced by C<die>, C<warn> and the C<carp> family of
commands, the program handles the problem immediately on the location
where the problem appears.  In the second approach, an I<exception>
is thrown on the spot where the problem is created, and then somewhere
else in the program the condition is handled.

The implementation of exceptions in Perl5 is done with a eval-die pair:
on the spot where the problem occurs, C<die> is called.  But, because of
the execution of that routine is placed within an C<eval>, the program
as a whole will not die, just the execution of a part of the program
will seize.  However, what if the condition which caused the routine to die
is solvable on a higher level?  Or what if the user of the code doesn't
bother that a part fails, because it has implemented alternatives for
that situation?  Exception handling is quite clumsy in Perl5.

The C<Log::Report> set of distributions let modules concentrate on the
program flow, and let the main program decide on the report handling
model.  The infrastructure to translate messages into multiple languages,
whether to create exceptions or carp/die, to collect longer explanations
with the messages, to log to mail or syslog, and so on, is decided in
pluggable back-ends.

=subsection The Reason for the report

Traditionally, perl has a very simple view on error reports: you
either have a warning or an error.  However, it would be much clearer
for user's and module-using applications, when a distinction is made
between various causes.  For instance, a configuration error is quite
different from a disk-full situation.  In C<Log::Report>, the produced
reports in the code tell I<what> is wrong.  The main application defines
loggers, which interpret the cause into (syslog) levels.

Defined by C<Log::Report> are

=over 4
=item . trace (debug, program)
The message will be used when some logger has debugging enabled.  The
messages show steps taken by the program, which are of interest by the
developers and maintainers of the code, but not for end-users.

=item . assert (program)
Shows an unexpected condition, but continues to run.  When you want the
program to abort in such situation, that use C<panic>.

=item . info (verbose, program)
These messages show larger steps in the execution of the program.
Experienced users of the program usually do not want to see all these
intermediate steps.  Most programs will display info messages (and
higher) when some C<verbose> flag is given on the command-line.

=item . notice (program)
An user may need to be aware of the program's accidental smart behavior,
for instance, that it initializes a lasting C<Desktop> directory in your
home directory.  Notices should be sparse.

=item . warning (program)
The program encountered some problems, but was able to work around it
by smart behavior.  For instance, the program does not understand a
line from a log-file, but simply skips the line.

=item . mistake (user)
When a user does something wrong, but what is correctable by smart
behavior of the program.  For instance, in some configuration file,
you can fill-in "yes" or "no", but the user wrote "yeah".  The program
interprets this as "yes", producing a mistake message as warning.

It is much nicer to tell someone that he/she made a mistake, than
to call that an error.

=item . error (user)
The user did something wrong, which is not automatically correctable
or the program is not willing to correct it automatically for reasons
of code quality.  For instance, an unknown option flag is given on the
command-line.  These are configuration issues, and have no useful
value in C<$!>.  The program will be stopped, usually before taken off.

=item . fault (system)
The program encountered a situation where it has no work-around.  For
instance, a file cannot be opened to be written.  The cause of that
problem can be some user error (i.e. wrong filename), or external
(you accidentally removed a directory yesterday).  In any case, the
C<$!> (C<$ERRNO>) variable is set here.

=item . alert (system)
Some external cause disturbs the execution of the program, but the
program stays alive and will try to continue operation.  For instance,
the connection to the database is lost.  After a few attempts, the
database can be reached and the program continues as if nothing happened.
The cause is external, so C<$!> is set.  Usually, a system administrator
needs to be informed about the problem.

=item . failure (system)
Some external cause makes it impossible for this program to continue.
C<$!> is set, and usually the system administrator wants to be
informed.  The program will die.

The difference with C<fault> is subtile and not always clear.  A fault
reports an error returned by an operating system call, where the failure
would report an operational problem, like a failing mount.

=item . panic (program)
All above report classes are expected: some predictable situation
is encountered, and therefore a message is produced.  However, programs
often do some internal checking.  Of course, these conditions should
never be triggered, but if they do... then we can only stop.

For instance, in an OO perl module, the base class requires all
sub-classes to implement a certain method.  The base class will produce
a stub method with triggers a panic when called.  The non-dieing version
of this test C<assert>.
=back

I<Debugging> or being C<verbose> are run-time behaviors, and have nothing
directly to do with the type of message which is produced.  These two
are B<modes> which can be set on the dispatchers: one dispatcher may
be more verbose that some other.

On purpose, we do not use the terms C<die> or C<fatal>, because the
dispatcher can be configured what to do in cause of which condition.
For instance, it may decide to stop execution on warnings as well.

The terms C<carp> and C<croak> are avoided, because the program cause
versus user cause distinction (warn vs carp) is reflected in the use
of different reasons.  There is no need for C<confess> and C<croak>
either, because the dispatcher can be configured to produce stack-trace
information (for a limited sub-set of dispatchers)

=subsection Report levels
Various frameworks used with perl programs define different labels
to indicate the reason for the message to be produced.

 Perl5 Log::Dispatch Syslog Log4Perl Log::Report
 print   0,debug     debug  debug    trace
 print   0,debug     debug  debug    assert
 print   1,info      info   info     info
 warn\n  2,notice    notice info     notice
 warn    3,warning   warn   warn     mistake
 carp    3,warning   warn   warn     warning
 die\n   4,error     err    error    error
 die     5,critical  crit   fatal    fault
 croak   6,alert     alert  fatal    alert  
 croak   7,emergency emerg  fatal    failure
 confess 7,emergency emerg  fatal    panic

=subsection Run modes
The run-mode change which messages are passed to a dispatcher, but
from a different angle than the dispatch filters; the mode changes
behavioral aspects of the messages, which are described in detail in
L<Log::Report::Dispatcher/Processing the message>.  However, it should
behave as you expect: the DEBUG mode shows more than the VERBOSE mode,
and both show more than the NORMAL mode.

=example extract run mode from Getopt::Long
The C<GetOptions()> function will count the number of C<v> options
on the command-line when a C<+> is after the option name.

 use Log::Report;
 use Getopt::Long qw(:config no_ignore_case bundling);

 my $mode;    # defaults to NORMAL
 GetOptions 'v+'        => \$mode
          , 'verbose=i' => \$mode
          , 'mode=s'    => \$mode
     or exit 1;

 dispatcher 'PERL', 'default', mode => $mode;

Now, C<-vv> will set C<$mode> to C<2>, as will C<--verbose 2> and
C<--verbose=2> and C<--mode=ASSERT>.  Of course, you do not need to
provide all these options to the user: make a choice.

=example the mode of a dispatcher
 my $mode = dispatcher(find => 'myname')->mode;

=example run-time change mode of a dispatcher
To change the running mode of the dispatcher, you can do
  dispatcher mode => DEBUG => 'myname';

However, be warned that this does not change the types of messages
accepted by the dispatcher!  So: probably you will not receive
the trace, assert, and info messages after all.  So, probably you
need to replace the dispatcher with a new one with the same name:
  dispatcher FILE => 'myname', to => ..., mode => 'DEBUG';

This may reopen connections (depends on the actual dispatcher), which
might be not what you wish to happened.  In that case, you must take
the following approach:

  # at the start of your program
  dispatcher FILE => 'myname', to => ...
     , accept => 'ALL';    # overrule the default 'NOTICE-' !!

  # now it works
  dispatcher mode => DEBUG => 'myname';    # debugging on
  ...
  dispatcher mode => NORMAL => 'myname';   # debugging off

Of course, this comes with a small overall performance penalty.

=subsection Exceptions

The simple view on live says: you 're dead when you die.  However,
more complex situations try to revive the dead.  Typically, the "die"
is considered a terminating exception, but not terminating the whole
program, but only some logical block.  Of course, a wrapper round
that block must decide what to do with these emerging problems.

Java-like languages do not "die" but throw exceptions which contain the
information about what went wrong.  Perl modules like C<Exception::Class>
simulate this.  It's a hassle to create exception class objects for each
emerging problem, and the same amount of work to walk through all the
options.

Log::Report follows a simpler scheme.  Fatal messages will "die", which is
caught with "eval", just the Perl way (used invisible to you).  However,
the wrapper gets its hands on the message as the user has specified it:
untranslated, with all unprocessed parameters still at hand.

 try { fault __x "cannot open file {file}", file => $fn };
 if($@)                         # is Log::Report::Dispatcher::Try
 {   my $cause = $@->wasFatal;  # is Log::Report::Exception
     $cause->throw if $cause->message->msgid =~ m/ open /;
     # all other problems ignored
 }

See M<Log::Report::Dispatcher::Try> and M<Log::Report::Exception>.

=section Comparison

Some notes on differences between the Log::Report approach and other
Perl concepts.

=subsection die/warn/Carp

Perl's built-in exception system is very primitive: "die" and "warn".
Most programming languages provide a much more detailed exception
mechanism.

A typical perl program can look like this:

 my $dir = '/etc';

 File::Spec->file_name is_absolute($dir)
     or die "ERROR: directory name must be absolute.\n";

 -d $dir
     or die "ERROR: what platform are you on?";

 until(opendir DIR, $dir)
 {   warn "ERROR: cannot read system directory $dir: $!";
     sleep 60;
 }

 print "Processing directory $dir\n"
     if $verbose;

 while(defined(my $file = readdir DIR))
 {   if($file =~ m/\.bak$/)
     {   warn "WARNING: found backup file $dir/$f\n";
         next;
     }

     die "ERROR: file $dir/$file is binary"
         if $debug && -B "$dir/$file";

     print "DEBUG: processing file $dir/$file\n"
         if $debug;

     open FILE, "<", "$dir/$file"
         or die "ERROR: cannot read from $dir/$f: $!";

     close FILE
         or croak "ERROR: read errors in $dir/$file: $!";
 }

Where C<die>, C<warn>, and C<print> are used for various tasks.  With
C<Log::Report>, you would write

 use Log::Report;

 # can be left-out when there is no debug/verbose
 dispatcher PERL => 'default', mode => 'DEBUG';

 my $dir = '/etc';

 File::Spec->file_name is_absolute($dir)
     or mistake "directory name must be absolute";

 -d $dir
     or panic "what platform are you on?";

 until(opendir DIR, $dir)
 {   alert "cannot read system directory $dir";
     sleep 60;
 }

 info "Processing directory $dir";

 while(defined(my $file = readdir DIR))
 {   if($file =~ m/\.bak$/)
     {   notice "found backup file $dir/$f";
         next;
     }

     assert "file $dir/$file is binary"
         if -B "$dir/$file";

     trace "processing file $dir/$file";

     unless(open FILE, "<", "$dir/$file")
     {   error "no permission to read from $dir/$f"
             if $!==ENOPERM;
         fault "unable to read from $dir/$f";
     }

     close FILE
         or failure "read errors in $dir/$file";
 }

A lot of things are quite visibly different, and there are a few smaller
changes.  There is no need for a new-line after the text of the message.
When applicable (error about system problem), then the C<$!> is added
automatically.

=subsection Log::Dispatch and Log::Log4perl
The two major logging frameworks for Perl are M<Log::Dispatch> and
M<Log::Log4perl>; both provide a pluggable logging interface.

Both frameworks do not have (gettext or maketext) language translation
support, which has various consequences.  When you wish for to report
in some other language, it must be translated before the logging
function is called.   This may mean that an error message is produced
in Chinese, and therefore also ends-up in the syslog file in Chinese.
When this is not your language, you have a problem.

Log::Report translates only in the back-end, which means that the user may
get the message in Chinese, but you get your report in your beloved Dutch.
When no dispatcher needs to report the message, then no time is lost in
translating.

With both logging frameworks, you use terminology comparable to
syslog: the module programmer determines the seriousness of the
error message, not the application which integrates multiple modules.
This is the way perl programs usually work, but often the cause for
inconsequent user interaction.

=subsection Locale::gettext and Locate::TextDomain

Both on GNU gettext based implementations can be used as translation
frameworks.  M<Locale::TextDomain> syntax is supported, with quite some
extensions. Read the excellent documentation of Locale::Textdomain.
Only the tried access via C<$__> and C<%__> are not supported.

The main difference with these modules is the moment when the translation
takes place.  In M<Locale::TextDomain>, an C<__x()> will result in an
immediate translation request via C<gettext()>.  C<Log::Report>'s version
of C<__x()> will only capture what needs to be translated in an object.
When the object is used in a print statement, only then the translation
will take place.  This is needed to offer ways to send different
translations of the message to different destinations.

To be able to postpone translation, objects are returned which stringify
into the translated text.

=cut

1;
