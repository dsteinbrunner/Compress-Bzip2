# -*- mode: perl -*-

use Test::More tests => 5;
#use Test::More qw(no_plan);

## compress sample2 from the bzip2 1.0.2 distribution
## compare against bzip2 command with od -x and diff

BEGIN {
  use_ok('Compress::Bzip2');
};

my $debugf = 0;
my $INFILE = 't/022-sample.txt';
my $PREFIX = 't/051-tmp';

my ( $in, $out, $d, $outbuf, $counter, $bytes, $bytesout, $flushcount, $bytesflushedmark );

open( $in, "< $INFILE" ) or die "$INFILE: $!";
open( $out, "> $PREFIX-out.bz2" ) or die "$PREFIX-out.bz2: $!";

## verbosity 0-4, small 0,1, blockSize100k 1-9, workFactor 0-250, readUncompressed 0,1
$d = bzdeflateInit( -verbosity => $debugf ? 4 : 0 );

ok( $d, "bzdeflateInit was successful" );

$counter = 0;
$bytes = 0;
$bytesout = 0;
$bytesflushedmark = 0;
$flushcount = 0;
while ( my $ln = sysread( $in, $buf, 512 ) ) {
  $outbuf = $d->bzdeflate( $buf );
  if ( !defined($outbuf) ) {
    print STDERR "error: $outbuf $bzerrno\n";
    last;
  }

  if ( $bytes - $bytesflushedmark > 50_000 && $outbuf eq '' ) {
    $outbuf = $d->bzflush;
    $flushcount++ if $outbuf;
    $bytesflushedmark = $bytes;
  }

  if ( $outbuf ne '' ) {
    syswrite( $out, $outbuf );
    $bytesout += length($outbuf);
  }

  $bytes += $ln;
  $counter++;
}

$outbuf = $d->bzclose;
if ( defined($outbuf) && $outbuf ne '' ) {
  syswrite( $out, $outbuf );
  $bytesout += length($outbuf);
  
  $counter++;
}

ok( $bytes && $bytesout, "$counter blocks read, $bytes bytes in, $bytesout bytes out" );
ok( $flushcount, "successful flushes at 50,000 - $flushcount" );

close($in);
close($out);

system( "bunzip2 < $PREFIX-out.bz2 | od -x > $PREFIX-reference-out-bunzip.odx" );
system( "od -x < $INFILE > $PREFIX-infile.odx" );
system( "diff -c $PREFIX-infile.odx $PREFIX-reference-out-bunzip.odx > $PREFIX-diff.txt" );

ok( ! -s "$PREFIX-diff.txt", "no differences with bzip2" );