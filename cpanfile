requires 'perl', '5.010001';

requires 'Data::UUID';
requires 'MIME::Base64';
requires 'Perl6::Export::Attrs';
requires 'URI::Escape';

on test => sub {
    requires 'Test::Exception';
    requires 'Test::More';
    requires 'Test::Perl::Critic';
    recommends 'Pod::Coverage', '0.18';
    recommends 'Test::CheckManifest', '0.9';
    recommends 'Test::Perl::Critic';
    recommends 'Test::Pod', '1.22';
    recommends 'Test::Pod::Coverage', '1.08';
};
