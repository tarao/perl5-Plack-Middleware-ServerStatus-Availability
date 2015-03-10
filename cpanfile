requires 'Plack::Middleware';
requires 'Plack::Builder';
requires 'Plack::Request';
requires 'Net::CIDR::Lite';
requires 'Path::Class';

on 'test' => sub {
    requires 'Test::Base';
    requires 'Test::More';
    requires 'Test::Requires';
    requires 'Plack';
    requires 'HTTP::Request';
    suggests 'Test::TCP';
    suggests 'Starlet';
    suggests 'Plack::Loader';
    suggests 'LWP::UserAgent';
};
