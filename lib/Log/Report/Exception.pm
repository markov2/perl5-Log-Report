use warnings;
use strict;

package Log::Report::Exception;

use Log::Report      'log-report';
use Log::Report::Util qw/is_fatal/;
use POSIX             qw/locale_h/;

=chapter NAME
Log::Report::Exception - a collected report

=chapter SYNOPSIS
 # created within a try block
 try { error "help!" };
 my $exception = $@->wasFatal;
 $exception->throw if $exception;

 $@->reportFatal;  # combination of above two lines

 my $message = $exception->message;   # the Log::Report::Message

 if($message->inClass('die')) ...
 if($exception->inClass('die')) ...   # same
 if($@->wasFatal(class => 'die')) ... # same

=chapter DESCRIPTION
In Log::Report, exceptions are not as extended as available in
languages as Java: you do not create classes for them.  The only
thing an exception object does, is capture some information about
an (untranslated) report.

=chapter OVERLOADING

=overload stringification
Produces "reason: message".
=cut

use overload '""' => 'toString';

=chapter METHODS

=section Constructors
=c_method new OPTIONS

=option  report_opts HASH
=default report_opts {}

=requires reason REASON
=requires message Log::Report::Message
=cut

sub new($@)
{   my ($class, %args) = @_;
    $args{report_opts} ||= {};
    bless \%args, $class;
}

=section Accessors

=method report_opts
=cut

sub report_opts() {shift->{report_opts}}

=method reason [REASON]
=cut

sub reason(;$)
{   my $self = shift;
    @_ ? $self->{reason} = uc(shift) : $self->{reason};
}

=method isFatal
Returns whether this exception has a severity which makes it fatal
when thrown.  See M<Log::Report::Util::is_fatal()>.
=example
  if($ex->isFatal) { $ex->throw(reason => 'ALERT') }
  else { $ex->throw }
=cut

sub isFatal() { is_fatal shift->{reason} }

=method message [MESSAGE]
Change the MESSAGE of the exception, must be a M<Log::Report::Message>
object.

When you use a C<Log::Report::Message> object, you will get a new one
returned. Therefore, if you want to modify the message in an exception,
you have to re-assign the result of the modification.

=examples
 $e->message->concat('!!')); # will not work!
 $e->message($e->message->concat('!!'));
 $e->message(__x"some message {msg}", msg => $xyz);
=cut

sub message(;$)
{   my $self = shift;
    @_ or return $self->{message};
    my $msg = shift;
    UNIVERSAL::isa($msg, 'Log::Report::Message')
        or panic __x"message() of exception expects Log::Report::Message";
    $self->{message} = $msg;
}

=section Processing

=method inClass CLASS|REGEX
Check whether any of the classes listed in the message match CLASS
(string) or the REGEX.  This uses M<Log::Report::Message::inClass()>.
=cut

sub inClass($) { $_[0]->message->inClass($_[1]) }

=method throw OPTIONS
Insert the message contained in the exception into the currently
defined dispatchers.  The C<throw> name is commonly known
exception related terminology for C<report>.

The OPTIONS overrule the captured options to M<Log::Report::report()>.
This can be used to overrule a destination.  Also, the reason can
be changed.

=example overrule defaults to report
 try { print {to => 'stderr'}, ERROR => 'oops!' };
 $@->reportFatal(to => 'syslog');

 $exception->throw(to => 'syslog');

 $@->wasFatal->throw(reason => 'WARNING');
=cut

sub throw(@)
{   my $self    = shift;
    my $opts    = @_ ? { %{$self->{report_opts}}, @_ } : $self->{report_opts};

    my $reason;
    if($reason = delete $opts->{reason})
    {   $self->{reason} = $reason;
        $opts->{is_fatal} = is_fatal $reason
            unless exists $opts->{is_fatal};
    }
    else
    {   $reason = $self->{reason};
    }

    $opts->{stack} = Log::Report::Dispatcher->collectStack
        if $opts->{stack} && @{$opts->{stack}};

    report $opts, $reason, $self;
}

# where the throw is handled is not interesting
sub PROPAGATE($$) {shift}

=method toString
Prints the reason and the message.  Differently from M<throw()>, this
only represents the textual content: it does not re-cast the exceptions to
higher levels.

=examples printing exceptions
 print $_->toString for $@->exceptions;
 print $_ for $@->exceptions;   # via overloading
=cut

sub toString()
{   my $self = shift;
    my $msg  = $self->message;
    lc($self->{reason}) . ': ' . (ref $msg ? $msg->toString : $msg) . "\n";
}

=method print [FILEHANDLE]
The default filehandle is STDOUT.

=examples
 print $exception;  # via overloading
 $exception->print; # OO style
=cut

sub print(;$)
{   my $self = shift;
    (shift || *STDERR)->print($self->toString);
}

1;
