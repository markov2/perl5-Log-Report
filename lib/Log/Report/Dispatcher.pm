use warnings;
use strict;

package Log::Report::Dispatcher;

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util qw/parse_locale expand_reasons %reason_code
  escape_chars/;

use POSIX      qw/strerror/;
use List::Util qw/sum/;
use Encode     qw/find_encoding FB_DEFAULT/;

eval { POSIX->import('locale_h') };
if($@)
{   no strict 'refs';
    *setlocale = sub { $_[1] }; *LC_ALL = sub { undef };
}

my %modes = (NORMAL => 0, VERBOSE => 1, ASSERT => 2, DEBUG => 3
  , 0 => 0, 1 => 1, 2 => 2, 3 => 3);
my @default_accept = ('NOTICE-', 'INFO-', 'ASSERT-', 'ALL');

my %predef_dispatchers = map { (uc($_) => __PACKAGE__.'::'.$_) }
   qw/File Perl Syslog Try/;

=chapter NAME
Log::Report::Dispatcher - manage dispatching

=chapter SYNOPSIS
 use Log::Report;

 # The following will be created for you automatically
 dispatcher 'PERL', 'default', accept => 'NOTICE-';
 dispatcher close => 'default';  # after deamonize

 dispatcher 'FILE', 'log'
   , mode => 'DEBUG', to => '/var/log/mydir/myfile';

 # Full package name is used, same as 'FILE'
 dispatcher Log::Report::Dispatch::File => 'stderr'
   , to => \*STDERR, accept => 'NOTICE-';

 # Within a "try" block, there is only one dispatcher
 dispatcher TRY => 'try';

=chapter DESCRIPTION
This base-class handles the creation of dispatchers, plus the
common filtering rules.  

See the L</DETAILS> section, below.

=chapter METHODS

=section Constructors

=c_method new TYPE, NAME, OPTIONS
Create a dispatcher.  The TYPE of back-end to start is required, and listed
in the L</DESCRIPTION> part of this manual-page. For various external
back-ends, special wrappers are created.

The NAME must be uniquely identifying this dispatcher.  When a second
dispatcher is created (via M<Log::Report::dispatcher()>) with the name
of an existing dispatcher, the existing one will get replaced.

All OPTIONS which are not consumed by this base constructor are passed
to the wrapped back-end.  Some of them will check whether all OPTIONS
are understood, other ignore unknown OPTIONS.

=option  accept REASONS
=default accept C<depend on mode>
See M<Log::Report::Util::expand_reasons()> for possible values.  If
the initial mode for this dispatcher does not need verbose or debug
information, then those levels will not be accepted.

When the mode equals C<NORMAL> (the default) then C<accept>'s default
is C<NOTICE->.  In case of C<VERBOSE> it will be C<INFO->, C<ASSERT>
results in C<ASSERT->, and C<DEBUG> in C<ALL>.

=option  locale LOCALE
=default locale <system locale>
Overrules the global setting.  Can be overruled by
M<Log::Report::report(locale)>.

=option  mode 'NORMAL'|'VERBOSE'|'ASSERT'|'DEBUG'|0..3
=default mode 'NORMAL'
Possible values are C<NORMAL> (or C<0> or C<undef>), which will not show
C<INFO> or debug messages, C<VERBOSE> (C<1>; shows C<INFO> not debug),
C<ASSERT> (C<2>; only ignores C<TRACE> messages), or C<DEBUG> (C<3>)
which shows everything.  See section L<Log::Report/Run modes>.

You are advised to use the symbolic mode names when the mode is
changed within your program: the numerical values are available
for smooth M<Getopt::Long> integration.

=option  format_reason 'UPPERCASE'|'LOWERCASE'|'UCFIRST'|'IGNORE'|CODE
=default format_reason 'LOWERCASE'
How to show the reason text which is printed before the message. When
a CODE is specified, it will be called with a translated text and the
returned text is used.

=option  charset CHARSET
=default charset <undef>
Convert the messages in the specified character-set (codeset).  By
default, no conversion will take place, because the right choice cannot
be determined automatically.

=cut

sub new(@)
{   my ($class, $type, $name, %args) = @_;

    my $backend
      = $predef_dispatchers{$type}          ? $predef_dispatchers{$type}
      : $type->isa('Log::Dispatch::Output') ? __PACKAGE__.'::LogDispatch'
      : $type->isa('Log::Log4perl')         ? __PACKAGE__.'::Log4perl'
      : $type;

    eval "require $backend";
    $@ and alert "cannot use class $backend:\n$@";

    (bless {name => $name, type => $type, filters => []}, $backend)
       ->init(\%args);
}

my %format_reason = 
  ( LOWERCASE => sub { lc $_[0] }
  , UPPERCASE => sub { uc $_[0] }
  , UCFIRST   => sub { ucfirst lc $_[0] }
  , IGNORE    => sub { '' }
  );

my $default_mode = 'NORMAL';

sub init($)
{   my ($self, $args) = @_;
    my $mode = $self->_set_mode(delete $args->{mode} || $default_mode);

    $self->{locale} = delete $args->{locale};

    my $accept = delete $args->{accept} || $default_accept[$mode];
    $self->{needs}  = [ expand_reasons $accept ];

    my $f = delete $args->{format_reason} || 'LOWERCASE';
    $self->{format_reason} = ref $f eq 'CODE' ? $f : $format_reason{$f}
        or error __x"illegal format_reason '{format}' for dispatcher",
             format => $f;

    my $csenc;
    if(my $cs  = delete $args->{charset})
    {   my $enc = find_encoding $cs
            or error __x"Perl does not support charset {cs}", cs => $cs;
        $csenc = sub { no warnings 'utf8'; $enc->encode($_[0]) };
    }

    $self->{charset_enc} = $csenc || sub { $_[0] };
    $self;
}

=method close
Terminate the dispatcher activities.  The dispatcher gets disabled,
to avoid the case that it is accidentally used.  Returns C<undef> (false)
if the dispatcher was already closed.
=cut

sub close()
{   my $self = shift;
    $self->{closed}++ and return undef;
    $self->{disabled}++;
    $self;
}

# horrible errors on some Perl versions if called during destruction
my $in_global_destruction = 0;
END { $in_global_destruction++ }
sub DESTROY { $in_global_destruction or shift->close }

#----------------------------

=section Accessors

=method name
Returns the unique name of this dispatcher.
=cut

sub name {shift->{name}}

=method type
The dispatcher TYPE, which is usually the same as the class of this
object, but not in case of wrappers like for Log::Dispatch.
=cut

sub type() {shift->{type}}

=method mode
Returns the mode in use for the dispatcher as number.  See M<new(mode)>
and L<Log::Report/Run modes>.
=cut

sub mode() {shift->{mode}}

#Please use C<dispatcher mode => $MODE;>
sub defaultMode($) {$default_mode = $_[1]}

# only to be used via Log::Report::dispatcher(mode => ...)
# because requires re-investigating collective dispatcher needs
sub _set_mode($)
{   my $self = shift;
    my $mode = $self->{mode} = $modes{$_[0]};
    defined $mode
        or error __x"unknown run mode '{mode}'", mode => $_[0];

    $self->{needs}  = [ expand_reasons $default_accept[$mode] ];

    info __x"switching to run mode {mode}, accept {accept}"
       , mode => $mode, accept => $default_accept[$mode];

    $mode;
}

# only to be called from Log::Report::dispatcher()!!
# because requires re-investigating needs
sub _disable($)
{   my $self = shift;
    @_ ? ($self->{disabled} = shift) : $self->{disabled};
}

=method isDisabled
=method needs
Returns the list with all REASONS which are needed to fulfill this
dispatcher's needs.  When disabled, the list is empty, but not forgotten.
=cut

sub isDisabled() {shift->{disabled}}
sub needs() { $_[0]->{disabled} ? () : @{$_[0]->{needs}} }

=section Logging

=method log HASH-of-OPTIONS, REASON, MESSAGE
This method is called by M<Log::Report::report()> and should not be called
directly.  Internally, it will call M<translate()>, which does most of
the work.
=cut

sub log($$$)
{   panic "method log() must be extended per back-end";
}

=method translate HASH-of-OPTIONS, REASON, MESSAGE
See L</Processing the message>, which describes the actions taken by
this method.  A string is returned, which ends on a new-line, and
may be multi-line (in case a stack trace is produced).
=cut

my %always_loc = map {($_ => 1)} qw/ASSERT PANIC/;
sub translate($$$)
{   my ($self, $opts, $reason, $msg) = @_;

    my $mode = $self->{mode};
    my $code = $reason_code{$reason}
        or panic "unknown reason '$reason'";

    my $show_loc
      = $always_loc{$reason}
     || ($mode==2 && $code >= $reason_code{WARNING})
     || ($mode==3 && $code >= $reason_code{MISTAKE});

    my $show_stack
      = $reason eq 'PANIC'
     || ($mode==2 && $code >= $reason_code{ALERT})
     || ($mode==3 && $code >= $reason_code{ERROR});

    my $locale
      = defined $msg->msgid
      ? ($opts->{locale} || $self->{locale})      # translate whole
      : Log::Report->_setting($msg->domain, 'native_language');

    # not all implementations of setlocale() return the old value
    my $oldloc = setlocale(&LC_ALL);
    setlocale(&LC_ALL, $locale || 'en_US');

    my $r = $self->{format_reason}->((__$reason)->toString);
    my $e = $opts->{errno} ? strerror($opts->{errno}) : undef;

    my $format
      = $r && $e ? N__"{reason}: {message}; {error}"
      : $r       ? N__"{reason}: {message}"
      : $e       ? N__"{message}; {error}"
      :            undef;

    my $text = defined $format
      ? __x($format, message => $msg->toString, reason => $r, error => $e
           )->toString
      : $msg->toString;
    $text .= "\n";

    if($show_loc)
    {   if(my $loc = exists $opts->{location} ? $opts->{location}
                   : [ $self->collectLocation ])
        {   my ($pkg, $fn, $line, $sub) = @$loc;
            # pkg and sub are missing when decoded by ::Die
            $text .= " "
                  . __x( 'at {filename} line {line}'
                       , filename => $fn, line => $line)->toString
                  . "\n";
        }
    }

    if($show_stack)
    {   my $stack
          = $opts->{stack} ||= $self->collectStack;

        foreach (@$stack)
        {   $text .= $_->[0] . " "
              . __x( 'at {filename} line {line}'
                   , filename => $_->[1], line => $_->[2] )->toString
              . "\n";
        }
    }

    setlocale(&LC_ALL, $oldloc)
        if defined $oldloc;

    $self->{charset_enc}->($text);
}

=method collectStack [MAXDEPTH]
Returns an ARRAY of ARRAYs with text, filename, line-number.
=cut

sub collectStack($)
{   my ($self, $max) = @_;

    my ($nest, $sub) = (1, undef);
    do { $sub = (caller $nest++)[3] }
    while(defined $sub && $sub ne 'Log::Report::report');
    defined $sub or $nest = 1;  # not found

    # skip syntax==SHORT routine entries
    $nest++ if defined $sub && $sub =~ m/^Log\:\:Report\:\:/;

    # special trick by Perl for Carp::Heavy: adds @DB::args
  { package DB;    # non-blank before package to avoid problem with OODoc

    my @stack;
    while(!defined $max || $max--)
    {   my ($pkg, $fn, $linenr, $sub) = caller $nest++;
        defined $pkg or last;

        my $line = $self->stackTraceLine(call => $sub, params => \@DB::args);
        push @stack, [$line, $fn, $linenr];
    }

    \@stack;
  }
}

=ci_method collectLocation
Collect the information to be displayed as line where the error occurred.
Probably, this needs improvement, where carp and die show different lines.
=cut

sub collectLocation()
{   my $thing = shift;
    my $nest  = 1;
    my @args;

    do {@args = caller $nest++}
    until $args[3] eq 'Log::Report::report';  # common entry point

    # skip syntax==SHORT routine entries
    @args = caller $nest++
        if +(caller $nest)[3] =~ m/^Log\:\:Report\:\:[^:]*$/;

    @args;
}

=ci_method stackTraceLine OPTIONS
=requires package CLASS
=requires filename STRING
=requires linenr INTEGER
=requires call STRING
=requires params ARRAY

=option  max_line INTEGER
=default max_line C<undef>

=option  max_params INTEGER
=default max_params 8

=option  abstract INTEGER
=default abstract 1
The higher the abstraction value, the less details are given
about the caller.  The minimum abstraction is specified, and
then increased internally to make the line fit within the C<max_line>
margin.
=cut

sub stackTraceLine(@)
{   my ($thing, %args) = @_;

    my $max       = $args{max_line}   ||= 500;
    my $abstract  = $args{abstract}   || 1;
    my $maxparams = $args{max_params} || 8;
    my @params    = @{$args{params}};
    my $call      = $args{call};

    my $obj = ref $params[0] && $call =~ m/^(.*\:\:)/ && UNIVERSAL::isa($params[0], $1)
      ? shift @params : undef;

    my $listtail  = '';
    if(@params > $maxparams)
    {   $listtail   = ', [' . (@params-$maxparams) . ' more]';
        $#params  = $maxparams -1;
    }

    $max        -= @params * 2 - length($listtail);  #  \( ( \,[ ] ){n-1} \)

    my $calling  = $thing->stackTraceCall(\%args, $abstract, $call, $obj);
    my @out      = map {$thing->stackTraceParam(\%args, $abstract, $_)} @params;
    my $total    = sum map {length $_} $calling, @out;

  ATTEMPT:
    while($total <= $max)
    {   $abstract++;
        last if $abstract > 2;  # later more levels

        foreach my $p (reverse 0..$#out)
        {   my $old  = $out[$p];
            $out[$p] = $thing->stackTraceParam(\%args, $abstract, $params[$p]);
            $total  -= length($old) - length($out[$p]);
            last ATTEMPT if $total <= $max;
        }

        my $old   = $calling;
        $calling  = $thing->stackTraceCall(\%args, $abstract, $call, $obj);
        $total   -= length($old) - length($calling);
    }

    $calling .'(' . join(', ',@out) . $listtail . ')';
}

# 1: My::Object(0x123141, "my string")
# 2: My::Object=HASH(0x1231451)
# 3: My::Object("my string")
# 4: My::Object()
#

sub stackTraceCall($$$;$)
{   my ($thing, $args, $abstract, $call, $obj) = @_;

    if(defined $obj)    # object oriented
    {   my ($pkg, $method) = $call =~ m/^(.*\:\:)(.*)/;
        return overload::StrVal($obj) . '->' . $call;
    }
    else                # imperative
    {   return $call;
    }
}

sub stackTraceParam($$$)
{   my ($thing, $args, $abstract, $param) = @_;
    defined $param
        or return 'undef';

    return $param   # int or float
        if $param =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;

    return overload::StrVal($param)
        if ref $param;

    '"' . escape_chars($param) . '"';
}

=chapter DETAILS

=section Available back-ends

When a dispatcher is created (via M<new()> or M<Log::Report::dispatcher()>),
you must specify the TYPE of the dispatcher.  This can either be a class
name, which extends a M<Log::Report::Dispatcher>, or a pre-defined
abbreviation of a class name.  Implemented are:

=over 4
=item M<Log::Report::Dispatcher::Perl> (abbreviation 'PERL')
Use Perl's own C<print()>, C<warn()> and C<die()> to ventilate
reports.  This is the default dispatcher.

=item M<Log::Report::Dispatcher::File> (abbreviation 'FILE')
Logs the message into a file, which can either be opened by the
class or be opened before the dispatcher is created.

=item M<Log::Report::Dispatcher::Syslog> (abbreviation 'SYSLOG')
Send messages into the system's syslog infrastructure, using
M<Sys::Syslog>.

=item C<Log::Dispatch::*>
All of the M<Log::Dispatch::Output> extensions can be used directly.
The M<Log::Report::Dispatcher::LogDispatch> will wrap around that
back-end.

=item C<Log::Log4perl>
Use the M<Log::Log4perl> main object to write to dispatchers.  This
infrastructure uses a configuration file.

=item M<Log::Report::Dispatcher::Try> (abbreviation 'TRY')
Used by M<Log::Report::try()>, it will translate reports into
exceptions.

=back

=section Processing the message

=subsection Addition information

The modules which use C<Log::Report> will only specify the base of
the message string.  The base dispatcher and the back-ends will extend
this message with additional information:

=over 4
=item . the reason
=item . the filename/line-number where the problem appeared
=item . the filename/line-number where it problem was reported
=item . the error text in C<$!>
=item . a stack-trace
=item . a trailing new-line
=back

When the message is a translatable object (M<Log::Report::Message>, for
instance created with M<Log::Report::__()>), then the added components
will get translated as well.  Otherwise, all will be in English.

Exactly what will be added depends on the actual mode of the dispatcher
(change it with M<mode()>, initiate it with M<new(mode)>).

                        mode mode mode mode
 REASON   SOURCE   TE!  NORM -v   -vv  -vvv
 trace    program  ...                 S
 assert   program  ...            SL   SL
 info     program  T..       S    S    S
 notice   program  T..  S    S    S    S
 mistake  user     T..  S    S    S    SL
 warning  program  T..  S    S    SL   SL
 error    user     TE.  S    S    SL   SC
 fault    system   TE!  S    S    SL   SC
 alert    system   T.!  S    S    SC   SC
 failure  system   TE!  S    S    SC   SC
 panic    program  .E.  SC   SC   SC   SC

 -v = verbose, -vv = debug, -vvv = trace
 T - usually translated
 E - exception
 ! - will include $! text
 B - leave block with exception
 D - delayed; only shown when block completes without error
 L - include filename and linenumber
 S - show/print when accepted
 C - stack trace (like Carp::confess())

=subsection Filters

With a filter, you can block or modify specific messages before
translation.  There may be a wish to change the REASON of a report
or its content.  It is not possible to avoid the exit which is
related to the original message, because a module's flow depends
on it to happen.

When there are filters defined, they will be called in order of
definition.  For each of the dispatchers which are called for a
certain REASON (which C<accept> that REASON), it is checked whether
its name is listed for the filter (when no names where specified,
then the filter is applied to all dispatchers).

When selected, the filter's CODE reference is called with four arguments:
the dispatcher object (a M<Log::Report::Dispatcher>), the HASH-of-OPTIONS
passed as optional first argument to M<Log::Report::report()>, the
REASON, and the MESSAGE.  Returned is the new REASON and MESSAGE.
When the returned REASON is C<undef>, then the message will be ignored
for that dispatcher.

Be warned about processing the MESSAGE: it is a M<Log::Report::Message>
object which may have a C<prepend> string and C<append> string or
object.  When the call to M<Log::Report::report()> contained multiple
comma-separated components, these will already have been joined together
using concatenation (see M<Log::Report::Message::concat()>.

=example a filter on syslog
 dispatcher filter => \&myfilter, 'syslog';

 # ignore all translatable and non-translatable messages containing
 # the word "skip"
 sub myfilter($$$$)
 {   my ($disp, $opts, $reason, $message) = @_;
     return () if $message->untranslated =~ m/\bskip\b/;
     ($reason, $message);
 }

=example take all mistakes and warnings serious
 dispatch filter => \&take_warns_serious;
 sub take_warns_serious($$$$)
 {   my ($disp, $opts, $reason, $message) = @_;
       $reason eq 'MISTAKE' ? (ERROR   => $message)
     : $reason eq 'WARNING' ? (FAULT   => $message)
     :                        ($reason => $message);
 }

=cut

1;
