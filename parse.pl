use warnings;
use strict;
use MIME::Base64;
use Data::Dumper;
use JSON;

our @charts = ();

open(my $fh, '<', 'music.dat');

while(my $line = <$fh>)
{
	# Decode the line, turn it into a hex string, break that into bytes, and filter the empty entries
	my @entry = grep { /\S/ } split(/(.{2})/, unpack("H*", decode_base64($line)));
	
	# Begin parsing
	my %parsedEntry = (
		# 'raw' => join(' ', @entry),
		'ID' => undef,
		'ArtistName' => undef,
		'SongTitle' => undef,
		'Streams' => undef,
		'DateRecorded' => undef
	);
	my $pointer = 0;
	while($pointer < $#entry)
	{
		# debug("Pointer: $pointer");
		# Entry ID
		if($entry[$pointer] eq '08')
		{
			# ID lives in the next index
			$parsedEntry{'ID'} = hex $entry[++$pointer];
			# Move the pointer
			$pointer++;
			next;
		}
		# Artist's Name
		elsif($entry[$pointer] eq '12')
		{
			# Get the length of the string
			my $length = hex $entry[++$pointer];
			# Clone the bytes out into another array
			#	Subtract one due to inclusive array cloning
			my @name = @entry[++$pointer..($pointer+$length-1)];
			# De-code the name
			$parsedEntry{'ArtistName'} = byteArrayToString(\@name);
			# Move the pointer to the end of the
			$pointer += $length;
			next;
		}
		# Song Title
		elsif($entry[$pointer] eq '1a')
		{
			# Get the length of the string
			my $length = hex $entry[++$pointer];
			# Clone the bytes out into another array
			#	Subtract one due to inclusive array cloning
			my @song = @entry[++$pointer..($pointer+$length-1)];
			# De-code the name
			$parsedEntry{'SongTitle'} = byteArrayToString(\@song);
			# Move the pointer to the end of the
			$pointer += $length;
			next;
		}
		# Stream Count
		elsif($entry[$pointer] eq '20')
		{
			# Four bytes make up the integer
			my @count = @entry[($pointer+1)..($pointer+4)];
			# Combine and convert to decimal
			$parsedEntry{'Streams'} = parseVarint(\@count);
			# Move the pointer
			$pointer += 5;
			next;
		}
		# Recorded Date
		elsif($entry[$pointer] eq '2a')
		{
			# Date field is always 8 bytes
			my $length = 8;
			# Clone the bytes out into another array
			# 	Skip the first bit, as it's filler
			my @date = @entry[($pointer+2)..($pointer+$length)];
			# De-code the name
			$parsedEntry{'DateRecorded'} = byteArrayToString(\@date);
			# Move the pointer to the end of the
			$pointer += $length;
			next;
		}
	}

	push(@charts, \%parsedEntry);
}

print encode_json(\@charts);

sub byteArrayToString
{
	return join('', map { chr(hex($_)); } @{ $_[0] });
}

sub parseVarint
{
	my @unparsed = map { hex($_) } @{ $_[0] };
	my @varint = ();
	my $decimal = 0;
	
	for(my $i = 0; $i < scalar @unparsed; $i++)
	{
		if($unparsed[$i] & 128)
		{
			$unparsed[$i] ^= 128;
		}
		
		unshift(@varint, $unparsed[$i]);
	}
	
	while(@varint)
	{
		$decimal += shift(@varint) * 128**(scalar @varint);
	}
	
	return $decimal;
}

sub debug
{
	print "\nDEBUG:\n\t$_[0]\n";
}

