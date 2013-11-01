#!/usr/bin/perl
#****************************************************************
#
#  Mail Delivery Settings Automation Program For extremeserv.
#
#                    auto_conf_update.pl
#
#                        DENET.CO.,LTD
#
#
#               Auther : onishi@MiDC 2013.10.30
#           Updated by : onishi@MiDC 2013.10.30
#               E mail : onishi@denet.co.jp
#***************************************************************

use strict;
use warnings;
use utf8;
use Encode qw(encode);
use Email::MIME;
use Email::MIME::Creator;
use Email::Sender::Simple qw(sendmail);
use Sys::Hostname;
use Net::OpenSSH;
use File::Copy qw(copy);
use Text::Diff qw(diff);


my ($sec,$min,$hour,$mday,$mon,$year) = (localtime(time))[0..5];
$year += 1900;
$mon  += 1;

my $date = $year.$mon.$mday.$hour.$min.$sec;
my $hostname = hostname();

my $user = '';
my $password = '';

my $from = '';
my $to   = '';
my $subject = '['.$hostname.'] Access,Transport,Verify was updated.';

my $access_fh;
my $transport_fh;
my $verify_fh;
my $server_lists_fh;
my $excep_lists_fh;
my $excep_flag = 0;

my $access_file = 'access.txt';
my $transport_file = 'transport.txt';
my $verify_file = 'verify.txt';
my $server_lists_file = 'server_lists.txt';
my $excep_lists_file = 'excep_lists.txt';

my $access_file_bk = $access_file . "_" . $date;
my $transport_file_bk = $transport_file . "_" . $date;
my $verify_file_bk = $verify_file . "_" .$date;

copy($access_file,$access_file_bk);
copy($transport_file,$transport_file_bk);
copy($verify_file,$verify_file_bk);

open($access_fh,"> $access_file");
open($transport_fh,"> $transport_file");
open($verify_fh,"> $verify_file");
open($server_lists_fh,"< $server_lists_file");
open($excep_lists_fh,"< $excep_lists_file");



while(<$server_lists_fh>){
	if($_ !~ /^#/){
		chomp $_;
		my $server = $_;
		print $access_fh "##### " . $_ . " mail domain lists start. #####\n";
		print $transport_fh "##### " . $_ . " mail domain lists start. #####\n";
		print $verify_fh "##### " . $_ . " mail domain lists start. #####\n";

		my $ssh = Net::OpenSSH->new(
				$_,
				(
					user => $user,
					password => $password,
				),
			);
		$ssh->error and die "Can't ssh connect to ". $_ . ": " . $ssh->error;
		my @mdomain = $ssh->capture('ls -la /var/qmail/mailnames|grep popuser|awk \'{print $9}\'');
		undef $ssh;
		
		foreach(@mdomain)
		{
			chomp $_;
			my $domain = $_;

			while(<$excep_lists_fh>){
				chomp $_;

				if(($_ !~ /^#/) && ($excep_flag == 0)){
					my ($tmp,$tmp2,$tmp3) = split / /, $_, 3;

					if($tmp eq $domain)
					{
						$excep_flag = 1;
					}else{
						$excep_flag = 0;
					}
				}
			}
			seek($excep_lists_fh,0,0);

			if($excep_flag == 0)
			{
				print $access_fh $domain . "    OK\n";
				print $transport_fh $domain . "    smtp:[" . $server . "]\n";
				print $verify_fh $domain . "    smtp:[" . $server . "]\n";
			}
			$excep_flag = 0;
		}
		print $access_fh "##### " . $_ . " mail domain lists end. #####\n";
		print $transport_fh "##### " . $_ . " mail domain lists end. #####\n";
		print $verify_fh "##### " . $_ . " mail domain lists end. #####\n";
	}
}

print $access_fh "##### exception handling domain lists start. #####\n";
print $transport_fh "##### exception handling domain lists start. #####\n";
print $verify_fh "##### exception handling domain lists start. #####\n";

while(<$excep_lists_fh>)
{
	chomp $_;

	if($_ !~ /^#/)
	{
		my ($domain,$transport,$verify) = split / /, $_, 3;
		print $access_fh $domain . "    OK\n";
		print $transport_fh $domain . "    " . $transport . "\n";
		print $verify_fh $domain . "    " . $verify . "\n";
	}
}

print $access_fh "##### exception handling domain lists end. #####\n";
print $transport_fh "##### exception handling domain lists end. #####\n";
print $verify_fh "##### exception handling domain lists end. #####\n";

close($server_lists_fh);
close($access_fh);
close($transport_fh);
close($verify_fh);
close($excep_lists_fh);

my $diff = diff($transport_file_bk,$transport_file,{ STYLE => "OldStyle"});
my $body = $diff;

if ( $diff eq '' )
{
	exit 1;
}
	
my $mail = Email::MIME->create(
	'header' => [
		'From' => encode('MIME-Header-ISO_2022_JP', $from),
		'To'   => encode('MIME-Header-ISO_2022_JP', $to),
		'Subject' => encode('MIME-Header-ISO_2022_JP', $subject),
		],
	'attributes' => {
		'content_type' => 'text/plain',
		'charset'      => 'ISO-2022-JP',
		'encoding'     => '7bit',
	},
	'body' => encode( 'iso-2022-jp', $body ),
	);

sendmail($mail);

exit 0;
