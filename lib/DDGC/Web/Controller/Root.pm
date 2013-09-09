package DDGC::Web::Controller::Root;
# ABSTRACT: Main web controller class

use Moose;
use Path::Class;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(namespace => '');

sub base :Chained('/') :PathPart('') :CaptureArgs(0) {
	my ( $self, $c ) = @_;

	if ( my ( $username, $password ) = $c->req->headers->authorization_basic ) {
		$c->authenticate({ username => $username, password => $password, }, 'users');
	}

	$c->stash->{template_layout} = [ 'base.tx' ];
	$c->stash->{ddgc_config} = $c->d->config;
	$c->stash->{xmpp_userhost} = $c->d->config->prosody_userhost;
	$c->stash->{prefix_title} = 'DuckDuckGo Community';
	$c->stash->{user_counts} = $c->d->user_counts;
	$c->stash->{page_class} = "texture";
	$c->stash->{errors} = [];

	$c->wiz_check;

	$c->add_bc('Home', $c->chained_uri('Root','index'));
}

sub captcha :Chained('base') :Args(0) {
	my ($self, $c) = @_;
	$c->stash->{not_last_url} = 1;
	$c->create_captcha();
}

sub country_flag :Chained('base') :Args(2) {
	my ( $self, $c, $size, $country_code ) = @_;
	$c->stash->{not_last_url} = 1;
	if ($country_code =~ m/(\w+)\.png$/) {
		$country_code = $1;
	}
	my $country = $c->d->rs('Country')->find({ country_code => $country_code });
	unless ($country) {
		$c->response->status(404);
		$c->response->body("Not found");
		return $c->detach;
	}
	$c->serve_static_file($country->flag($size));
}

sub generated_css :Chained('base') :Args(1) {
	my ( $self, $c, $filename ) = @_;
	$c->stash->{not_last_url} = 1;
	my $file = file($c->d->config->cachedir,'generated_css',$filename)->stringify;
	if (-f $file) {
		$c->serve_static_file($file);
		return;
	}
	$c->response->status(404);
	$c->response->body("Not found");
	return $c->detach;
}

sub generated_images :Chained('base') :Args(1) {
	my ( $self, $c, $filename ) = @_;
	$c->stash->{not_last_url} = 1;
	my $file = file($c->d->config->cachedir,'generated_images',$filename)->stringify;
	if (-f $file) {
		$c->serve_static_file($file);
		return;
	}
	$c->response->status(404);
	$c->response->body("Not found");
	return $c->detach;
}

sub media :Chained('base') :Args {
	my ( $self, $c, @args ) = @_;
	$c->stash->{not_last_url} = 1;
	my $filename = join("/",@args);
	my $mediadir = $c->d->config->mediadir;
	my $file = file($mediadir,$filename);
	unless (-f $file) {
		$c->response->status(404);
		$c->response->body("Not found");
		return $c->detach;
	}
	$c->serve_static_file($file);
}

sub index :Chained('base') :PathPart('') :Args(0) {
	my ($self, $c) = @_;
	$c->stash->{not_last_url} = 1;
	$c->stash->{no_breadcrumb} = 1;
	$c->stash->{title} = 'Welcome to the DuckDuckGo Community Platform';
	$c->stash->{page_class} = "page-home texture";
}

sub default :Chained('base') :PathPart('') :Args {
	my ( $self, $c ) = @_;
	$c->stash->{not_last_url} = 1;
	$c->response->status(404);
	$c->add_bc('Not found', '');
}

sub end : ActionClass('RenderView') {
	my ( $self, $c ) = @_;
	my $template = $c->action.'.tx';

	push @{$c->stash->{template_layout}}, $template;

	$c->session->{last_url} = $c->req->uri unless $c->stash->{not_last_url};

	if ($c->user) {
		$c->stash->{user_notification_count} = $c->user->event_notifications_undone_count;
		$c->run_after_request(sub { $c->d->envoy->update_own_notifications });
	}

	$c->wiz_post_check;
}

no Moose;
__PACKAGE__->meta->make_immutable;
