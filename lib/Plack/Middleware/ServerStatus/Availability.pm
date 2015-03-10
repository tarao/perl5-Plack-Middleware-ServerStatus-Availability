package Plack::Middleware::ServerStatus::Availability;
use strict;
use warnings;

use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(path file allow);
use Plack::Request;
use Net::CIDR::Lite;

our $VERSION = "0.01";

sub prepare_app {
    my ($self) = @_;
    unless ($self->path->{status}) {
        warn sprintf "[%s] 'path.status' is not provided.", __PACKAGE__;
    }
    unless ($self->path->{control}) {
        warn sprintf "[%s] 'path.control' is not provided.", __PACKAGE__;
    }
    unless ($self->file) {
        warn sprintf "[%s] 'file' is not provided.", __PACKAGE__;
    }
    unless ($self->allow) {
        warn sprintf "[%s] 'allow' is not provided.", __PACKAGE__;
    }

    if ($self->allow) {
        my @allow = ref $self->allow ? @{$self->allow} : ($self->allow);
        my $ip = { v4 => [], v6 => [] };
        push @{$ip->{$_ =~ /:/ ? 'v6' : 'v4'}}, $_ for @allow;
        $self->{__cidr} = {};
        for my $v (qw(v4 v6)) {
            if (@{$ip->{$v}}) {
                my $cidr = Net::CIDR::Lite->new();
                $cidr->add_any($_) for @{$ip->{$v}};
                $self->{__cidr}->{$v} = $cidr;
            }
        }
    }
};

sub call {
    my ($self, $env) = @_;

    my $req = Plack::Request->new($env);
    my $addr = $env->{REMOTE_ADDR};
    if ($self->path->{status} and $self->path->{status} eq $req->path
            and $req->method eq 'GET' and $self->file) {
        return $self->respond(403, 'Forbidden') unless $self->allowed($addr);
        if ($self->status->is_available) {
            return $self->respond(200, 'OK');
        } else {
            return $self->respond(503, 'Server is up but is under maintenance');
        }
    }
    if ($self->path->{control} and $self->path->{control} eq $req->path
            and $req->method eq 'POST' and $self->file) {
        return $self->respond(403, 'Forbidden') unless $self->allowed($addr);
        my $action = $req->param('action');
        if ($action eq 'up') {
            $self->status->up;
            return $self->respond(200, 'Done');
        } elsif ($action eq 'down') {
            $self->status->down;
            return $self->respond(200, 'Done');
        } else {
            return $self->respond(400, 'Bad action');
        }
    }

    return $self->app->($env);
}

sub allowed {
    my ($self, $addr) = @_;
    my $v = ( $addr =~ /:/ ? 'v6' : 'v4' );
    return unless $self->{__cidr}->{$v};
    return $self->{__cidr}->{$v}->find($addr);
}

sub status {
    my $file = $_[0]->file;
    return Plack::Middleware::ServerStatus::Availability::Status->new($file);
}

sub respond {
    my ($self, $code, $reason) = @_;
    return [ $code, [ 'Content-Type' => 'text/plain' ], [ "$code $reason" ] ];
}

package Plack::Middleware::ServerStatus::Availability::Status;
use Path::Class;

sub new {
    my ($class, $file) = @_;
    return bless { file => file($file) }, $class;
}

sub is_available {
    return -f $_[0]->{file};
}

sub up {
    my $file = $_[0]->{file};
    $file->dir->mkpath;
    my $fh = $file->openw;
    printf $fh "%d\n", time;
    close $fh;
}

sub down {
    $_[0]->{file}->remove;
}

package Plack::Middleware::ServerStatus::Availability;

1;
__END__
