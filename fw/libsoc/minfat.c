/*
Copyright 2005, 2006, 2007 Dennis van Weeren
Copyright 2008, 2009 Jakub Bednarski
Copyright 2021 Alastair M. Robinson

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

This is a simple FAT16/FAT32 handler. It works on a sector basis to allow fastest acces on disk
images.

11-12-2005 - first version, ported from FAT1618.C

JB:
2008-10-11  - added SeekFile() and cluster_mask
            - limited file create and write support added
2009-05-01  - modified LoadDirectory() and GetDirEntry() to support sub-directories (with limitation of 511 files/subdirs per directory)
            - added GetFATLink() function
            - code cleanup
2009-05-03  - modified sorting algorithm in LoadDirectory() to display sub-directories above files
2009-08-23  - modified ScanDirectory() to support page scrolling and parent dir selection
2009-11-22  - modified FileSeek()
            - added FileReadEx()
2009-12-15  - all entries are now sorted by name with extension
            - directory short names are displayed with extensions

2012-07-24  - Major changes to fit the MiniSOC project - AMR
2021-02-20  - Adapted for the MiST firmware replacement project.  Directory-handling fixes  -  AMR
*/

#define NULL 0
#include <sys/types.h>
#include <stdio.h>
#include <string.h>

#include "hw/spi.h"

#include "swap_be.h"

#include "minfat.h"

#define tolower(x) (x|32)

#define CLUSTER_EOC (fat32 ? 0x0fffffff : 0xffff)

// internal global variables
unsigned int fat32;                // volume format is FAT32
uint32_t fat_start;                // start LBA of first FAT table
uint32_t fat_size;
uint32_t fat_number;
uint32_t data_start;               // start LBA of data field
uint32_t root_directory_cluster;   // root directory cluster (used in FAT32)
uint32_t root_directory_start;     // start LBA of directory table
uint32_t root_directory_size;      // size of directory region in sectors
unsigned int cluster_size;             // size of a cluster in sectors
uint32_t cluster_mask;             // binary mask of cluster number
unsigned int dir_entries;             // number of entry's in directory table

uint32_t cachedsector=-1;

static struct {
	uint32_t startcluster;
	uint32_t start;
	uint32_t sector;
	uint32_t cluster;
	uint32_t index;
} current_directory;

unsigned char sector_buffer[512];       // sector buffer
#ifndef DISABLE_LONG_FILENAMES
char longfilename[261];
#endif

//unsigned char *sector_buffer=0x18000;

//struct PartitionEntry partitions[4]; 	// [4];	// lbastart and sectors will be byteswapped as necessary

#define fat_buffer (*(FATBUFFER*)&sector_buffer) // Don't need a separate buffer for this.
// uint32_t buffered_fat_index;       // index of buffered FAT sector


//#define STATUS(x) puts(x);
#define STATUS(x)

#define FAT_DEBUG

#ifdef FAT_DEBUG
#define DBG(x) printf(x)
#define PDBG(x,y) printf(x,y)
#else
#define DBG(x)
#define PDBG(x,y)
#endif

const char* FAT32_ID="FAT32   ";
const char* FAT16_ID="FAT16   ";

// FindDrive() checks if a card is present and contains FAT formatted primary partition
unsigned int FindDrive(void)
{
	uint32_t boot_sector;
	int partitioncount;

	fat_start=0;

	fat32=0;

	STATUS("Reading MBR\n");

    if (!sd_read_sector(0, sector_buffer)) // read MBR
	{
		STATUS("Read of MBR failed\n");
        return(0);
	}

	STATUS("MBR successfully read\n");

	boot_sector=0;
	partitioncount=1;

	// If we can identify a filesystem on block 0 we don't look for partitions
    if (strncmp((const char*)&sector_buffer[0x36], FAT16_ID,8)==0) // check for FAT16
		partitioncount=0;
    if (strncmp((const char*)&sector_buffer[0x52], FAT32_ID,8)==0) // check for FAT32
		partitioncount=0;

	PDBG("Partitioncount %d\n",partitioncount);

	if(partitioncount)
	{
		// We have at least one partition, parse the MBR.
		struct MasterBootRecord *mbr=(struct MasterBootRecord *)sector_buffer;
		struct PartitionEntry *pe=(struct PartitionEntry *)&mbr->Partition[0][0];

		boot_sector = pe->startlba;
		if(mbr->Signature==0x55aa)
				boot_sector=ConvBBBB_LE(pe->startlba);
		else if(mbr->Signature!=0xaa55)
		{
			STATUS("No part sig");
			return(0);
		}
		PDBG("Reading boot sector %x\n",boot_sector);

		if (!sd_read_sector(boot_sector, sector_buffer)) // read discriptor
		    return(0);
//		hexdump(sector_buffer,512);
		STATUS("Boot sector...");
	}

	STATUS("Seeking FS...");

    if (strncmp(sector_buffer+0x52, FAT32_ID,8)==0) // check for FAT16
		fat32=1;
	else if (strncmp(sector_buffer+0x36, FAT16_ID,8)!=0) // check for FAT32
	{
        STATUS("Unsupported partition type!\r");
		return(0);
	}

    if (sector_buffer[510] != 0x55 || sector_buffer[511] != 0xaa)  // check signature
        return(0);

    // check for near-jump or int16_t-jump opcode
    if (sector_buffer[0] != 0xe9 && sector_buffer[0] != 0xeb)
        return(0);

    // check if blocksize is really 512 bytes
    if (sector_buffer[11] != 0x00 || sector_buffer[12] != 0x02)
        return(0);

    // get cluster_size
    cluster_size = sector_buffer[13];

    // calculate cluster mask
    cluster_mask = cluster_size - 1;

	PDBG("Cluster size: %d\n",cluster_size);
	PDBG("Cluster mask, %d\n",cluster_mask);

    fat_start = boot_sector + sector_buffer[0x0E] + (sector_buffer[0x0F] << 8); // reserved sector count before FAT table (usually 32 for FAT32)
	fat_number = sector_buffer[0x10];

    if (fat32)
    {
        if (strncmp((const char*)&sector_buffer[0x52], FAT32_ID,8) != 0) // check file system type
            return(0);

        dir_entries = cluster_size << 4; // total number of dir entries (16 entries per sector)
        root_directory_size = cluster_size; // root directory size in sectors
        fat_size = sector_buffer[0x24] + (sector_buffer[0x25] << 8) + (sector_buffer[0x26] << 16) + (sector_buffer[0x27] << 24);
        data_start = fat_start + (fat_number * fat_size);
        root_directory_cluster = sector_buffer[0x2C] + (sector_buffer[0x2D] << 8) + (sector_buffer[0x2E] << 16) + ((sector_buffer[0x2F] & 0x0F) << 24);
        root_directory_start = (root_directory_cluster - 2) * cluster_size + data_start;
    }
    else
    {
    	int i;
        // calculate drive's parameters from bootsector, first up is size of directory
        i = sector_buffer[17] + (sector_buffer[18] << 8);
        root_directory_size = ((i << 5) + 511) >> 9;

        // calculate start of FAT,size of FAT and number of FAT's
        fat_size = sector_buffer[22] + (sector_buffer[23] << 8);

        // calculate start of directory
        root_directory_start = fat_start + (fat_number * fat_size);
        root_directory_cluster = 0; // unused

        // calculate start of data
        data_start = root_directory_start + root_directory_size;
    }

	ChangeDirectoryByCluster(0);

    return(1);
}


/* FAT and Cluster manipulation functions, static to hide from external code */

static int SetCluster(uint32_t cluster, uint32_t target)
{
	uint32_t idx;
	uint32_t sb;
	int i;
    if (fat32)
    {
        sb = cluster >> 7; // calculate sector number containing FAT-link
        idx = cluster & 0x7F; // calculate link offset within sector
    }
    else
    {
        sb = cluster >> 8; // calculate sector number containing FAT-link
        idx = cluster & 0xFF; // calculate link offset within sector
    }

	sb+=fat_start;
	if(cachedsector!=sb)
	{
		cachedsector=sb;
		if (!sd_read_sector(sb, (unsigned char*)&fat_buffer))
		    return(0);
	}

	// mark cluster as used
	if (fat32)
		fat_buffer.fat32[idx] = ConvBBBB_LE(target);
	else
		fat_buffer.fat16[idx] = ConvBB_LE(target);

	// update FAT copies
	for (i = 0; i < fat_number; i++)
	{
		if (!sd_write_sector(sb + (i * fat_size), (unsigned char*)&fat_buffer))
		{
			printf("FAT copy #%u write failed!\r", i);
			return(0);
		}
	}
	return(1);
}


static uint32_t NextCluster(uint32_t cluster)
{
	uint32_t i;
	uint32_t sb;
    if (fat32)
    {
        sb = cluster >> 7; // calculate sector number containing FAT-link
        i = cluster & 0x7F; // calculate link offset within sector
    }
    else
    {
        sb = cluster >> 8; // calculate sector number containing FAT-link
        i = cluster & 0xFF; // calculate link offset within sector
    }

	sb+=fat_start;
	if(cachedsector!=sb)
	{
		cachedsector=sb;
		if (!sd_read_sector(sb, (unsigned char*)&fat_buffer))
		    return(0);
	}

    i = fat32 ? ConvBBBB_LE(fat_buffer.fat32[i]) & 0x0FFFFFFF : ConvBB_LE(fat_buffer.fat16[i]); // get FAT link
	return(i);
}


/* Find and allocate a free cluster in the FAT, and optionally append it to an existing cluster chain. */
static uint32_t AllocateCluster(uint32_t parent)
{
	int fat_index = 0; // first sector of FAT
	int buffer_index = 2;  // two first entries are reserved
	int buffer_size = fat32 ? 128 : 256;
	while (fat_index < fat_size)
	{
		cachedsector = fat_start + fat_index;
		if(!sd_read_sector(cachedsector, (unsigned char *)&fat_buffer))
		{
			printf("FAT read failed\n");
			return(0);
		}

		while (buffer_index < buffer_size)
		{
			if ((fat32 ? fat_buffer.fat32[buffer_index] : fat_buffer.fat16[buffer_index]) == 0)
			{
				uint32_t cluster = (fat_index << (fat32 ? 7 : 8)) + buffer_index;  // calculate cluster number
//				printf("Empty cluster: %u\n", cluster);
				SetCluster(cluster,CLUSTER_EOC);
				if(parent)
					SetCluster(parent,cluster);
				return(cluster);
			}
			++buffer_index;
		}
		buffer_index=0;
		++fat_index;
	}
	printf("Unable to find empty cluster\n");
	return(0);
}


static void ReleaseCluster(uint32_t cluster)
{
	uint32_t nextcluster;
	while(cluster)
	{
		nextcluster=NextCluster(cluster);
		SetCluster(cluster,0);
		if(nextcluster == CLUSTER_EOC)
			nextcluster=0;
		cluster=nextcluster;
	}
}


/* Filesystem functions callable from user code */


DIRENTRY *FindDirEntry(const char *name)
{
	DIRENTRY *p=0;
	while(p=NextDirEntry(p==NULL,0,0))
	{
#ifndef DISABLE_LONG_FILENAMES
		if(strcasecmp(longfilename,name)==0)
			break;
#endif
		if(strncasecmp((const char*)p->Name, name,11)==0)
			break;
	}
	return(p);
}


int ClusterFromDirEntry(const DIRENTRY *p)
{
	int result = 0;
	if(p)
	{
		result=ConvBB_LE(p->StartCluster);
		result += (fat32 ? (ConvBB_LE(p->HighCluster) & 0x0FFF) << 16 : 0);
	}
	return(result);
}


unsigned int FileOpen(fileTYPE *file, const char *name)
{
    DIRENTRY      *p = NULL;        // pointer to current entry in sector buffer
	int bm;

	/* Reject null or empty filenames, since an empty filename will match a file with no long filename. */
	if(!name || !name[0])
		return(0);

	file->size=0;
	p=FindDirEntry(name);

	if(p)
	{
		file->size = ConvBBBB_LE(p->FileSize);
		file->cluster = ClusterFromDirEntry(p);
		file->sector = 0;
		file->firstcluster=file->cluster;
		file->cursor=0;
		file->eof=0;
		file->dirsector=current_directory.sector-1;
		file->dirindex=current_directory.index-1;

#ifdef CONFIG_FILEBOOKMARKS
		for(bm=0;bm<CONFIG_FILEBOOKMARKS;++bm)
		{
			file->bookmarks[bm].sector=0;
			file->bookmarks[bm].cluster=file->cluster;
		}
		file->bookmark_threshold=(file->size>>9)/(8*CONFIG_FILEBOOKMARKS);
#endif

		return(1);
	}

    return(0);
}


void FileNextSector(fileTYPE *file,int count,int append)
{
    uint32_t sb;
    uint16_t i;
	count+=file->sector;
	while((file->sector ^ count)&~cluster_mask)
	{
		uint32_t c=NextCluster(file->cluster);
		if(c==CLUSTER_EOC)
		{
//			printf("At end of cluster, append : %d\n",append);
			c=0;
			if(append)
				c=AllocateCluster(file->cluster);
			if(!c)
				file->eof=1;
		}
		file->cluster=c;
		file->sector+=cluster_size;
	}
	file->sector=count;
}


unsigned int FileReadSector(fileTYPE *file, unsigned char *pBuffer)
{
    uint32_t sb;

    sb = data_start;                         // start of data in partition
    sb += cluster_size * (file->cluster-2);  // cluster offset
    sb += file->sector & cluster_mask;       // sector offset in cluster
	cachedsector=sb;
    return(sd_read_sector(sb, pBuffer));     // read sector from drive
}


unsigned int FileWriteSector(fileTYPE *file, unsigned char *pBuffer)
{
    uint32_t sb;

    sb = data_start;                         // start of data in partition
    sb += cluster_size * (file->cluster-2);  // cluster offset
    sb += file->sector & cluster_mask;       // sector offset in cluster
	cachedsector=sb;
	if(((file->sector+1)<<9)>file->size)
	{
		file->size+=512;
		file->dirty=1;
	}
    return(sd_write_sector(sb, pBuffer));    // write sector to drive
}

#ifdef CONFIG_FILEBOOKMARKS

void DumpBookmarks(fileTYPE *file)
{
	int idx;
	for(idx=0;idx<CONFIG_FILEBOOKMARKS;++idx)
	{
		printf("(Bookmark %d, %x, %x)\n",idx,file->bookmarks[idx].sector,file->bookmarks[idx].cluster);
	}
}


int BestBookmark(fileTYPE *file, uint32_t pm)
{
	int idx,best;
	int32_t bestd,d;
	best=-1;
	bestd=0x7fffffff;
	for(idx=0;idx<CONFIG_FILEBOOKMARKS;++idx)
	{
		d=pm-file->bookmarks[idx].sector;
		if(d>=0 && d<bestd)
		{
			best=idx;
			bestd=d;
		}
	}
	return(best);
}


/* Find the least useful bookmark */
int WorstBookmark(fileTYPE *file)
{
	int idx,idx2;
	uint32_t worstd=0x7fffffff;
	int worst=-1;
	for(idx=0;idx<CONFIG_FILEBOOKMARKS;++idx)
	{
		for(idx2=0;idx2<CONFIG_FILEBOOKMARKS;++idx2)
		{
			int d=file->bookmarks[idx2].sector-file->bookmarks[idx].sector;
			if(idx!=idx2 && (d<worstd))
			{
				worst=idx2;
				worstd=d;
			}
		}
	}
	return(worst);
}


void FileSeek(fileTYPE *file, uint32_t pos)
{
	uint32_t p=pos>>9;
	uint32_t pm=p&~cluster_mask;

	uint32_t currentsector=file->sector&~cluster_mask;
	uint32_t cluster=file->cluster;

	if(pm==currentsector)	// Is the new position within the same cluster?
	{
		file->sector=p;
	}
	else	// Crossing a cluster boundary
	{
		int idx;
		idx=BestBookmark(file,pm);
		if(idx>=0)
		{
//			printf("Found bookmark %d for %x (%x, %x)\n",idx,pm,file->bookmarks[idx].sector,file->bookmarks[idx].cluster);
			file->sector=file->bookmarks[idx].sector;
			file->cluster=file->bookmarks[idx].cluster;
		}
		else
		{
//			printf("No bookmark found\n");
			file->sector=0;
			file->cluster=file->firstcluster;
		}

		/* record bookmark */
		p-=file->sector;

		idx=BestBookmark(file,currentsector);

		/* We don't bother bookmarking at the start of the file, or if we're within bookmark_threshold of an existing bookmark */
		if((currentsector>file->bookmark_threshold) && (idx>=0)
			&& ((currentsector-file->bookmarks[idx].sector) > file->bookmark_threshold))
		{
			idx=WorstBookmark(file);
			file->bookmarks[idx].sector=currentsector;
			file->bookmarks[idx].cluster=cluster;
//			file->bookmark_index=file->bookmark_index==CONFIG_FILEBOOKMARKS-1 ? 0 : file->bookmark_index+1;
		}

		FileNextSector(file,p,0);
	}
	FileReadSector(file, sector_buffer);
	file->cursor=pos;
}
#else
void FileSeek(fileTYPE *file, uint32_t pos)
{
	uint32_t p=pos;
	if(p<(file->cursor&(~cluster_mask)))
	{
		file->sector=0;
		file->cursor=0;
		file->cluster=file->firstcluster;
	}
	else
		p-=file->cursor&~511;
	FileNextSector(file,p>>9,0);
	FileReadSector(file, sector_buffer);
	file->cursor=pos;
}
#endif

unsigned int FileRead(fileTYPE *file, unsigned char *buffer, int count)
{
	unsigned char *p;
	int c;
	uint32_t curs;
	uint32_t result;
	if(count+file->cursor>file->size)
		count=file->size-file->cursor;
	if(count<=0)
		return(0);
	result=count;
	curs=file->cursor&0x1ff;
	if(curs)
	{
		c=512-curs;
		p=sector_buffer+curs;
		if(c>count)
			c=count;
		file->cursor+=c;
		count-=c;
		while(c--)
			*buffer++=*p++;
		if(count)
			FileNextSector(file,1,0);
	}
	while(count>0)
	{
		if(count>511)
		{
			FileReadSector(file, buffer);
			buffer+=512;
			file->cursor+=512;
			count-=512;
			FileNextSector(file,1,0);
			if(!count)	/* Make sure we don't leave a stale sector buffer */
				FileReadSector(file, sector_buffer);
		}
		else
		{
			FileReadSector(file, sector_buffer);
			p=sector_buffer;
			file->cursor+=count;
			while(count--)
				*buffer++=*p++;
		}
	}
	return(result);
}


int FileGetCh(fileTYPE *file)
{
	if (!(file->cursor&0x1ff)) {
		// reload buffer
		if(file->cursor)
			FileNextSector(file,1,0);
		FileReadSector(file, sector_buffer);
	}
	if (file->cursor >= file->size)
		return EOF;
	else
		return (sector_buffer[(file->cursor++)&0x1ff]);
}


int LoadFileAbs(const char *fn, unsigned char *buf)
{
	fileTYPE file;
	if(FileOpen(&file,fn))
	{
		uint32_t c=0;
		STATUS("Opened file, loading...\n");

		while(c<file.size)
		{
			if(!FileReadSector(&file,buf))
				return(0);
			buf+=512;
			c+=512;
			if(c<file.size)
				FileNextSector(&file,1,0);
		}
	}
	else
	{
		PDBG("Can't open %s\n",fn);
		return(0);
	}
	return(1);
}


void ChangeDirectoryByCluster(uint32_t cluster)
{
	if(cluster)
	{
		current_directory.startcluster=cluster;
	    current_directory.start = data_start + cluster_size * (current_directory.startcluster - 2);
		dir_entries = cluster_size << 4;
	}
	else
	{
		current_directory.startcluster = root_directory_cluster;
		current_directory.start = root_directory_start;
		dir_entries = root_directory_size << 4; // 16 entries per sector
	}
}


uint32_t CurrentDirectory()
{
	return(current_directory.startcluster == root_directory_cluster ? 0 : current_directory.startcluster);
}


void ChangeDirectory(DIRENTRY *p)
{
	uint32_t cluster=ClusterFromDirEntry(p);
	ChangeDirectoryByCluster(cluster);
}


int MatchDirEntry(DIRENTRY *dir,int (*matchfunc)(const unsigned char *fn, int len, void *userdata),void *userdata)
{
	const unsigned char *fn=&dir->Name[0];
	int ll=11;
	if(!matchfunc)
		return((fn[0] != SLOT_EMPTY) && (fn[0] != SLOT_DELETED)); /* exclude deleted / empty slots by default */
#ifndef DISABLE_LONG_FILENAMES
	if(longfilename[0])
	{
		fn=longfilename;
		ll=65535;
	}
#endif
	return(matchfunc(fn,ll,userdata));
}


DIRENTRY *NextDirEntry(int init,int (*matchfunc)(const unsigned char *fn,int len,void *userdata),void *userdata)
{
	static DIRENTRY      *pEntry = NULL;        // pointer to current entry in sector buffer
	int prevlfn=0;

	if(init)
	{
		current_directory.index=0;
		current_directory.sector=current_directory.start;
		current_directory.cluster=current_directory.startcluster;
	}
#ifndef DISABLE_LONG_FILENAMES
	longfilename[13]=0;
#endif

	while(1)
	{
		while (current_directory.index<dir_entries)
		{
			if ((current_directory.index & 0x0F) == 0) // first entry in sector, load the sector
			{
				cachedsector=current_directory.sector;
				sd_read_sector(current_directory.sector++, sector_buffer);
				pEntry = (DIRENTRY*)sector_buffer;
			}
			else
				pEntry++;
			++current_directory.index;

//            if (pEntry->Name[0] != SLOT_EMPTY && pEntry->Name[0] != SLOT_DELETED) // valid entry??
//			{
			#ifndef DISABLE_LONG_FILENAMES
			if (pEntry->Attributes == ATTR_LFN)	// Do we have a long filename entry?
			{
				unsigned char *p=&pEntry->Name[0];
				int seq=p[0];
				int offset=((seq&0x1f)-1)*13;
				char *o=&longfilename[offset];
				*o++=p[1];
				*o++=p[3];
				*o++=p[5];
				*o++=p[7];
				*o++=p[9];

				*o++=p[0xe];
				*o++=p[0x10];
				*o++=p[0x12];
				*o++=p[0x14];
				*o++=p[0x16];
				*o++=p[0x18];

				*o++=p[0x1c];
				*o++=p[0x1e];
				prevlfn=1;
			}
			#else
			if(0)
			{

			}
			#endif
			else if (!(pEntry->Attributes & ATTR_VOLUME))
			{
#ifndef DISABLE_LONG_FILENAMES
				if(!prevlfn)
					longfilename[0]=0;
#endif
				prevlfn=0;
				// FIXME - should check the lfn checksum here.
				if((pEntry->Attributes & ATTR_DIRECTORY) || MatchDirEntry(pEntry,matchfunc,userdata))
					return(pEntry);
			}
			else
			{
#ifndef DISABLE_LONG_FILENAMES
				longfilename[13]=0;
#endif
				prevlfn=0;
			}
		}
//		}
//		printf("current_directory.index %d is >= dir_entries %d\n",current_directory.index,dir_entries);

		if (current_directory.start || fat32) // subdirectory is a linked cluster chain
		{
			current_directory.cluster = NextCluster(current_directory.cluster); // get next cluster in chain
			 // check if end of cluster chain
			if (fat32 ? (current_directory.cluster & 0x0FFFFFF8) == 0x0FFFFFF8 : (current_directory.cluster & 0xFFF8) == 0xFFF8)
				break; // no more clusters in chain

			current_directory.sector = data_start + cluster_size * (current_directory.cluster - 2); // calculate first sector address of the new cluster
			current_directory.index=0;
		}
		else
			break;
	}
    return(0);
}


int FindByCluster(uint32_t parent, uint32_t cluster)
{
    DIRENTRY      *p = NULL;        // pointer to current entry in sector buffer
	ChangeDirectoryByCluster(parent);
	while(p=NextDirEntry(p==NULL,0,0))
	{
		if(ClusterFromDirEntry(p)==cluster)
			return(1);
	}
	return(0);
}


// Verify that a directory cluster is valid by recursively tracing ".." entries back up to the root,
// then verifying that each directory entry exists within its parent.
// Returns 0 on failure
int ValidateDirectory(uint32_t directory)
{
    DIRENTRY      *pEntry = NULL;        // pointer to current entry in sector buffer
	uint32_t cluster;
	uint32_t sector;
	int index;
	if(!directory || (directory==root_directory_cluster))
	{
		return(1);
	}
    else // subdirectory
    {
        cluster = directory;
        sector = data_start + cluster_size * (cluster - 2);
    }
	cachedsector=sector;
    if(!sd_read_sector(sector++, sector_buffer)) // root directory is linear
		return(0);
    pEntry = (DIRENTRY*)sector_buffer;
    for (index = 0; index < 16; index++)	// 16 entries in a single sector.  Assume ".." will be in the first sector.
    {
        if (pEntry->Name[0] != SLOT_EMPTY && pEntry->Name[0] != SLOT_DELETED) // valid entry??
        {
            if (pEntry->Attributes & ATTR_DIRECTORY) // is this a directory
            {
                if (strncmp((const char*)pEntry->Name, "..         ", sizeof(pEntry->Name)) == 0)
                {
					unsigned long parent=ClusterFromDirEntry(pEntry);

					/* Safer, but requires more resources */
                    return(ValidateDirectory(parent) && FindByCluster(parent,directory));

					/* Lighter-weight version, merely checks that a path can be traced to the root. */
/*                    return(ValidateDirectory(parent)); */
                }
            }
        }
        pEntry++;
    }
	return(0);
}

int FilesystemPresent()
{
	return(fat_start!=0);
}

void _INIT_4_MinFAT(void) /* Requires SPI interface to be initialised */
{
	int t;
	printf("Searching for partition table\n");
	if(FindDrive())
		return;
	printf("SD Initialisation failed\n");
}


static int matchfreeentry(const unsigned char *fn, int len, void *userdata)
{
	printf("(%s)\n",fn);
	return(fn[0] == SLOT_EMPTY || fn[0] == SLOT_DELETED);
}


/* Find a free directory entry */
DIRENTRY *FindFreeDirEntry(fileTYPE *file)
{
	DIRENTRY *p=0;
	if(!file)
		return(0);
	do {
		p=NextDirEntry(p==0,&matchfreeentry,0);
	} while(p && (p->Attributes && ATTR_DIRECTORY));
	if(p)
	{
		file->dirsector=current_directory.sector-1;
		file->dirindex=current_directory.index-1;
		printf("Found free directory entry at %d, %d\n",file->dirsector,file->dirindex);
		printf("%x\n",(int)p);
		file->dirty=1;
	}
	return(p);
}


/* Read the current file's directory entry - for modification and re-writing.
   Be aware that the entry resides in the sector buffer. */
DIRENTRY *GetDirEntry(fileTYPE *file)
{
	DIRENTRY *result=0;
	if(file)
	{
		cachedsector=file->dirsector;
		if(sd_read_sector(file->dirsector,sector_buffer))
		{
			result=(DIRENTRY *)sector_buffer;
			result+=(file->dirindex&0x0f);
		}
	}
	return(result);
}

/* Write the dir entry back to disk.  Must still be in the sector_buffer, and no disk operations
   can have taken place since GetDirEntry(), hence this being non-public. */
static void WriteDirEntry(fileTYPE *file)
{
	printf("Writing directory entry to %d\n",file->dirsector);
	if(file)
		sd_write_sector(file->dirsector,sector_buffer);
}


void FileClose(fileTYPE *file)
{
	if(file)
	{
		if(file->dirty)
		{
			/* Do we have a partial write to store to disk? */
			if(file->cursor&511)
				FileWriteSector(file,sector_buffer);
			/* Update the file size */
			printf("Updating directory entry\n");
			DIRENTRY *p=GetDirEntry(file);
			if(p)
			{
				printf("%x\n",(int)p);
				printf("Updating file %s\n",&p->Name[0]);
				printf("Old size %d\n",p->FileSize);
				p->FileSize = ConvBBBB_LE(file->size);
				WriteDirEntry(file);
				file->dirty=0;
			}		
		}
	}
}


void SetFilename(fileTYPE *file, const char *filename)
{
	if(file)
	{
		if(file->dirty)
		{
			/* Update the filename */
			DIRENTRY *p=GetDirEntry(file);
			if(p)
			{
				memset(&p->Name[0],0,11); /* Clear filename */
				strncpy(&p->Name[0],filename,11);
				WriteDirEntry(file);
			}		
		}
	}
}


void FileDelete(fileTYPE *file)
{
	if(file)
	{
		DIRENTRY *p=0;
		ReleaseCluster(file->firstcluster);
		if(p=GetDirEntry(file))
		{
			p->Name[0]=SLOT_DELETED;
			WriteDirEntry(file);
		}	
	}
}


int FileCreate(fileTYPE *file,const char *filename)
{
	int result=0;
	if(!file)
		return(0);
	memset(file,0,sizeof(fileTYPE));
	if(FileOpen(file,filename))
		printf("Error - file already exists\n");
	else
	{
		DIRENTRY *p;
		printf("File not found, creating\n");
		
		printf("Allocating cluster\n");
		if(!(file->firstcluster=AllocateCluster(0)))
		{
			printf("Failed to allocate cluster\n");
			return(0);
		}

		printf("Finding free directory entry\n");
		if(p=FindFreeDirEntry(file))
		{
			printf("Existing contents: %s, %x\n",&p->Name[0],ConvBBBB_LE(p->FileSize));
			memcpy((void*)p->Name, filename, 11);
			p->Attributes = ATTR_NORMAL;
			p->CreateDate = ConvBB_LE(FILEDATE(2023, 7, 1));
			p->CreateTime = ConvBB_LE(FILETIME(0, 0, 0));
			p->AccessDate = ConvBB_LE(FILEDATE(2023, 7, 1));
			p->ModifyDate = ConvBB_LE(FILEDATE(2023, 7, 1));
			p->ModifyTime = ConvBB_LE(FILETIME(0, 0, 0));
			p->StartCluster = (unsigned short)ConvBB_LE(file->firstcluster); // for 68000
			p->HighCluster = fat32 ? (unsigned short)ConvBB_LE(file->firstcluster >> 16) : 0; // for 68000
			p->FileSize = 0;

			WriteDirEntry(file);
			file->cluster=file->firstcluster;
			result=1;
		}
		else
		{
			printf("Couldn't find free direntry, releasing allocated cluster\n");
			/* Free newly-allocated cluster */
			ReleaseCluster(file->firstcluster);
		}
	}
	return(result);
}

#if 0 
// changing of allocated cluster number is not supported - new size must be within current cluster number
unsigned int UpdateEntry(fileTYPE *file)
{
    DIRENTRY *pEntry;

    if (!MMC_Read(file->entry.sector, sector_buffer))
    {
        printf("UpdateEntry(): directory read failed!\r");
        return(0);
    }

    pEntry = (DIRENTRY*)sector_buffer;
    pEntry += file->entry.index;
    memcpy((void*)pEntry->Name, file->name, 11);
    pEntry->Attributes = file->attributes;

    if ((ConvBBBB_LE(pEntry->FileSize) + cluster_size - 1) / (cluster_size << 9) != (file->size + cluster_size - 1) / (cluster_size << 9))
    {
        printf("UpdateEntry(): different number of clusters!\r");
        printf("pEntry->FileSize = %lu\r", ConvBBBB_LE(pEntry->FileSize));
        printf("file->size = %lu\r", file->size);
        printf("cluster_size = %u\r", cluster_size);
        return(0);
    }

      pEntry->FileSize = ConvBBBB_LE(file->size); // for 68000

    if (!MMC_Write(file->entry.sector, sector_buffer))
    {
        printf("UpdateEntry(): directory write failed!\r");
        return(0);
    }

    return(1);
}

#endif

