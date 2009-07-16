use warnings;
use strict;

package Log::Report::Exception;

use Log::Report 'log-report';
use POSIX  qw/locale_h/;

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
=method reason
=method message
=cut

sub report_opts() {shift->{report_opts}}
sub reason()      {shift->{reason}}
sub message()     {shift->{message}}

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
=cut

# if we would used "report" here, we get a naming conflict with
# function Log::Report::report.
sub throw(@)
{   my $self   = shift;
    my $opts   = @_ ? { %{$self->{report_opts}}, @_ } : $self->{report_opts};
    my $reason = delete $opts->{reason} || $self->reason;
    report $opts, $reason, $self->message;
}

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
    $self->reason . ": " . $self->message . "\n";
}

1;
