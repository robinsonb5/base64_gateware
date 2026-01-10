// romgen.c
//
// Program to turn a binary file into a VHDL lookup table.
//   by Adam Pierce
//   29-Feb-2008
//
// Modified by Alastair M. Robinson
//
// This software is free to use by anyone for any purpose.
//
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h> 
#include <getopt.h>

typedef unsigned char BYTE;

struct RomGenOptions
{
	int offset;
	int limit;
	int byteswap;
	int	word;
	int size;
};

int ParseOptions(int argc,char **argv,struct RomGenOptions *opts)
{
	static struct option long_options[] =
	{
		{"help",no_argument,NULL,'h'},
		{"offset",required_argument,NULL,'o'},
		{"limit",required_argument,NULL,'l'},
		{"word",no_argument,NULL,'w'},
		{"byteswap",no_argument,NULL,'b'},
		{"size",required_argument,NULL,'s'},
		{0, 0, 0, 0}
	};

	/* Set defaults */
	opts->limit=0x7fffffff;
	opts->offset=0;
	opts->byteswap=0;
	opts->word=0;
	opts->size=4;

	while(1)
	{
		int c;
		c = getopt_long(argc,argv,"ho:l:wbs:",long_options,NULL);
		if(c==-1)
			break;
		switch (c)
		{
			case 'h':
				printf("Usage: %s [options] <filename>\n",argv[0]);
				printf("    -h --help\t  display this message\n");
				printf("    -w --word\t  output as word-oriented rather than byte-oriented.\n");
				printf("    -o --offset\t  skip a number of bytes before outputting ROM data.\n");
				printf("    -l --limit\t  stop after a specified number of bytes of ROM data.\n");
				printf("    -b --byteswap\t  reverse the byte order of the ROM data.\n");
				printf("    -s --size\t  number of bytes in each word of the ROM data.\n");
				break;
			case 'o':
				opts->offset=atoi(optarg);
				break;
			case 'l':
				opts->limit=atoi(optarg);
				break;
			case 'b':
				opts->byteswap=1;
				break;
			case 's':
				opts->size=atoi(optarg);
				break;
			case 'w':
				opts->word=1;
				break;
		}
	}
	return(optind);
}


int main(int argc, char **argv)
{
	int result=0;
	unsigned char *buf=0;
	FILE     *fd;
	int     addr = 0;
	int i;
	struct RomGenOptions opts;
	ssize_t s;

	i=ParseOptions(argc,argv,&opts);

	// Check the user has given us an input file.
	if(i>=argc)
	return 1;

	if(!opts.size)
		return 1;

	buf=malloc(opts.size);

	// Open the input file.
	fd = fopen(argv[i],"rb");
	if(!fd)
	{
		perror("File Open");
		return 2;
	}

	while(addr<(opts.limit/4))
	{
		int i;
		// Read 32 bits.
		if(opts.offset)
		{
			while(opts.offset>0)
			{
				s = fread(buf, 1, opts.size, fd);
				opts.offset-=4;
			}
		}
		s = fread(buf, 1, opts.size, fd);
		if(s==0)
		{
			if(feof(fd))
				break; // End of file
			else
			{
				perror("File read");
				result=3;
				goto end;
			}
		}
		for(i=s;i<opts.size;++i)
			buf[i]=0;

		// Output to STDOUT.

		if(opts.word)
		{
			printf("\t%6d => x\"",addr++);
			for(i=0;i<opts.size;++i)
			{
				if(opts.byteswap)
					printf("%02x",buf[opts.size-1-i]);
				else
					printf("%02x",buf[i]);
			}
			printf("\",\n");
		}
		else
		{
			printf("\t%6d => (",addr++);
			for(i=0;i<opts.size;++i)
			{
				if(opts.byteswap)
					printf("x\"%02x\"",buf[opts.size-1-i]);
				else
					printf("x\"%02x\"",buf[i]);
				if(i<opts.size-1)
					printf(",");
			}
			printf("),\n");
		}
	}
	/* Finally output a suitable "others => ..." line */
	if(opts.word)
	{
		printf("\tothers => x\"");
		for(i=0;i<opts.size;++i)
		{
			printf("00");
		}
		printf("\");\n");
	}
	else
	{
		printf("\tothers => (others => x\"00\"));\n");
	}

end:
	if(buf)
		free(buf);
	fclose(fd);
	return 0;
}

