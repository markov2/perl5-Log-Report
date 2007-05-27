use warnings;
use strict;

package Log::Report::Dispatcher::File;
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use IO::File;

=chapter NAME
Log::Report::Dispatcher::File - send messages to a file or file-handle

=chapter SYNOPSIS
 # automatically created when STDERR is open
 dispatcher Log::Report::Dispatcher::File => 'stderr'
   , to => \*STDERR, accept => 'NOTICE-';

 # disable default dispatcher
 dispatcher close => 'stderr';

 # let dispatcher open and close the file
 dispatcher FILE => 'mylog', to => '/var/log/mylog'
   , charset => 'utf-8';
 ...
 dispatcher close => 'mylog';  # will close file

 # open yourself, then also close yourself
 open OUT, ">:encoding('iso-8859-1')", '/var/log/mylog'
     or fault "...";
 dispatcher FILE => 'mylog', to => \*OUT;
 ...
 dispatcher close => 'mylog';  
 close OUT;

 # dispatch into a scalar
 my $output = '';
 open $outfile, '>', \$output;
 dispatcher FILE => 'into-scalar', to => \$outfile;
 ...
 dispatcher close => 'into-scalar';
 print $output;

=chapter DESCRIPTION
This basic file logger accepts an file-handle or filename as destination.

=chapter METHODS

=section Constructors

=c_method new TYPE, NAME, OPTIONS
=requires to FILENAME|FILEHANDLE|FILE-OBJECT
You can either specify a FILENAME, which is opened in append mode, or
any kind of handle or object which accepts supports C<print()>.
When cleaning-up the dispatcher, the file will only be closed in case
of a FILENAME.

=option  charset STRING
=default charset 'utf-8'
Only used in combination with a FILENAME.

=option  replace BOOLEAN
=default replace C<false>
Only used in combination with a FILENAME: throw away the old file
if it exists.  Probably you wish to append to existing information.
=cut

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    my $name = $self->name;
    my $to   = delete $args->{to}
        or error __x"dispatcher {name} needs parameter 'to'", name => $name;

    if(ref $to)
    {   $self->{output} = $to;
        trace "opened dispatcher $name to a ".ref($to);
    }
    else
    {   $self->{filename} = $to;
        my $mode    = $args->{replace} ? '>' : '>>';
        my $charset = delete $args->{charset} || 'utf-8';
        my $binmode = "$mode:encoding($charset)";

        $self->{output} = IO::File->new($to, $binmode)
            or fault __x"cannot write log into {file} with {binmode}"
                   , binmode => $binmode, file => $to;

        trace "opened dispatcher $name to $to with $binmode";
    }

    $self;
}

=method close
Only when initiated with a FILENAME, the file will be closed.  In any
other case, nothing will be done.
=cut

sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    $self->{output}->close if $self->{filename};
    $self;
}

=section Accessors

=method filename
Returns the name of the opened file, or C<undef> in case this dispatcher
was started from a file-handle or file-object.
=cut

sub filename() {shift->{filename}}

=section Logging
=cut

sub log($$$)
{   my $self = shift;
    $self->{output}->print($self->SUPER::translate(@_));
}

1;
