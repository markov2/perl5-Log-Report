use strict;
use warnings;

package Log::Report::DBIC::Profiler;
use base 'DBIx::Class::Storage::Statistics';

use Log::Report  import => 'trace';
use Time::HiRes  qw(time);

=chapter NAME

Log::Report::DBIC::Profiler - query profiler for DBIx::Class

=chapter SYNOPSIS

  use Log::Report::DBIC::Profiler;
  $schema->storage->debugobj(Log::Report::DBIC::Profiler->new);
  $schema->storage->debug(1);

  # And maybe (if no exceptions expected from DBIC)
  $schema->exception_action(sub { panic @_ });
  
  # Log to syslog
  use Log::Report;
  dispatcher SYSLOG => 'myapp'
    , identity => 'myapp'
    , facility => 'local0'
    , flags    => "pid ndelay nowait"
    , mode     => 'DEBUG';

=chapter DESCRIPTION

This profile will log M<DBIx::Class> queries via M<Log::Report> to a
selected back-end (via a dispatcher, see M<Log::Report::Dispatcher>)

=cut

my $start;

sub print($) { trace $_[1] }

sub query_start(@)
{   my $self = shift;
    $self->SUPER::query_start(@_);
    $start   = time;
}

sub query_end(@)
{   my $self = shift;
    $self->SUPER::query_end(@_);
    trace sprintf "execution took %0.4f seconds elapse", time-$start;
}

1;

