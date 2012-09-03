use warnings;
use strict;

package Log::Report::Dispatcher::Callback;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report';

=chapter NAME
Log::Report::Dispatcher::Callback - call a code-ref for each log-line

=chapter SYNOPSIS
 sub cb($$$)
 {   my ($disp, $options, $reason, $message) = @_;
     ...
 }

 dispatcher Log::Report::Dispatcher::Callback => 'cb'
    , callback => \&cb;

 dispatcher CALLBACK => 'cb'   # same
    , callback => \&cb;

=chapter DESCRIPTION
This basic file logger accepts a callback, which is called for each
message which is to be logged. When you need complex things, you
may best make your own extension to M<Log::Report::Dispatcher>, but
for simple things this will do.

=example
  sub send_mail($$$)
  {   my ($disp, $options, $reason, $message) = @_;
      my $msg = Mail::Send->new(Subject => $reason
        , To => 'admin@localhost');
      my $fh  = $msg->open('sendmail');
      print $fh $disp->translate($reason, $message);
      close $fh;
  }

  dispatcher CALLBACK => 'mail', callback => \&send_mail;

=chapter METHODS

=section Constructors

=c_method new TYPE, NAME, OPTIONS

=requires callback CODE
Your C<callback> is called with four parameters: this dispatcher object,
the options, a reason and a message.  The C<options> are the first
parameter of M<Log::Report::report()> (read over there).  The C<reason>
is a capitized string like C<ERROR>. Finally, the C<message> is a
M<Log::Report::Message>.

=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    $self->{callback} = $args->{callback}
        or error __x"dispatcher {name} needs a 'callback'", name => $self->name;

    $self;
}

=section Accessors

=method callback
Returns the code reference which will handle each logged message.
=cut

sub callback() {shift->{callback}}

=section Logging
=cut

sub log($$$)
{   my $self = shift;
    $self->{callback}->($self, @_);
}

1;