#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <stdint.h>
#include <limits.h>
#include "disassembler.h"
#include "syms.h"
#include "debug.h"
#include "cpu.h"
#include "backend.h"
#include "ticks.h"

#define BUFF_SIZE       0x10000

static void disassemble_loop(int start, int end);

unsigned char *mem;
int  c_cpu = CPU_Z80;
int  c_adl_mode = 0;
char *c_target = NULL;
int  inverted = 0;
int  c_autolabel = 0;
int  c_source = 0;   /* -c: annotate with C source lines */

/* Simple source-file line cache. */
#define SRC_CACHE_MAX 8
static struct {
    char   path[PATH_MAX];
    char **lines;
    int    count;
} src_cache[SRC_CACHE_MAX];
static int src_cache_size = 0;

static const char *get_source_line(const char *filename, int lineno)
{
    int i;
    for (i = 0; i < src_cache_size; i++) {
        if (strcmp(src_cache[i].path, filename) == 0)
            goto found;
    }
    /* Load the file. */
    if (src_cache_size < SRC_CACHE_MAX) {
        FILE *fp = fopen(filename, "r");
        if (!fp) return NULL;
        i = src_cache_size++;
        strncpy(src_cache[i].path, filename, PATH_MAX - 1);
        src_cache[i].path[PATH_MAX - 1] = '\0';
        src_cache[i].lines = NULL;
        src_cache[i].count = 0;
        char line[1024];
        while (fgets(line, sizeof(line), fp)) {
            src_cache[i].lines = realloc(src_cache[i].lines,
                                         (src_cache[i].count + 1) * sizeof(char *));
            /* Strip trailing newline. */
            size_t len = strlen(line);
            while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r'))
                line[--len] = '\0';
            src_cache[i].lines[src_cache[i].count++] = strdup(line);
        }
        fclose(fp);
    } else {
        return NULL;
    }
found:
    if (lineno < 1 || lineno > src_cache[i].count) return NULL;
    return src_cache[i].lines[lineno - 1];
}


static void usage(char *program)
{
    printf("z88dk disassembler\n\n");
    printf("%s [+target] [options] [file]\n\n",program);
    printf("  +target        Enable extended disassembly for target\n");
    printf("  -x <file>      Symbol file to read\n");
    printf("                 Use before -o,-s,-e to enable symbols\n");
    printf("  -c             Annotate disassembly with C source lines (requires -x)\n");
    printf("  -o <addr>      Address to load code to\n");
    printf("  -s <addr>      Address to start disassembling from\n");
    printf("  -e <addr>      Address to stop disassembling at\n\n");
    printf("  -k <count>     Skip count bytes in the input file\n");
    printf("  -mz80          Disassemble z80 code\n");
    printf("  -mz180         Disassemble z180 code\n");
    printf("  -mez80_z80     Disassemble ez80 (short) code\n");
    printf("  -mez80         Disassemble ez80 ADL code\n");
    printf("  -mz80n         Disassemble z80n code\n");
    printf("  -mr2ka         Disassemble Rabbit 2000A code\n");
    printf("  -mr3k          Disassemble Rabbit 3000 code\n");
    printf("  -mr4k          Disassemble Rabbit 4000 code\n");
    printf("  -mr5k          Disassemble Rabbit 5000 code\n");
    printf("  -mr6k          Disassemble Rabbit 6000 code\n");
    printf("  -mr800         Disassemble R800 code\n");
    printf("  -mgbz80        Disassemble Gameboy z80 code\n");
    printf("  -m8080         Disassemble 8080 code (with z80 mnemonics)\n");
    printf("  -m8085         Disassemble 8085 code (with z80 mnemonics)\n");
    printf("  -mvm1          Disassemble KR580VM1 code (with z80 mnemonics)\n");
    printf("  -mkc160        Disassemble KC160\n");
    printf("  -mkc160_z80    Disassemble KC160 in Z80 mode\n");
    
    exit(1);
}

static backend_t disassembler_backend = {
    .get_memory = get_memory
};

int main(int argc, char **argv)
{
    char  *program = argv[0];
    char  *endp;
    unsigned int    org = 0;
    int    start = -1;
    int    skip = 0;
    int    end = INT_MAX;
    int    loaded = 0;
    int    symbol_addr = -1;

    mem = calloc(1,BUFF_SIZE);

    if ( argc == 1 ) {
        usage(program);
    }

    set_backend(disassembler_backend);

    while ( argc > 1  ) {
        if (argv[1][0] == '+' ) {
            c_target = &argv[1][1];
            argc--; argv++;
        } else if( argv[1][0] == '-' && argv[2] ) {
            switch (argc--, argv++[1][1]){
            case 'o':
                symbol_addr = symbol_resolve(argv[1], NULL);
                org = (-1 == symbol_addr) ? strtol(argv[1], &endp, 0) : symbol_addr;
                if ( start == -1 ) {
                    start = org;
                }
                argc--; argv++;
                break;
            case 's':
                symbol_addr = symbol_resolve(argv[1], NULL);
                start = (-1 == symbol_addr) ? strtol(argv[1], &endp, 0) : symbol_addr;
                argc--; argv++;
                break;
            case 'e':
                symbol_addr = symbol_resolve(argv[1], NULL);
                end = (-1 == symbol_addr) ? strtol(argv[1], &endp, 0) : symbol_addr;
                argc--; argv++;
                break;
            case 'c':
                c_source = 1;
                break;
            case 'i':
                inverted = 255;
                break;
            case 'a':
                c_autolabel = 1;
                break;
            case 'k':
                skip = strtol(argv[1], &endp, 0);
                argc--; argv++;
                break;
            case 'x':
                read_symbol_file(argv[1]);
                argc--; argv++;
                break;
            case 'm':
                if ( strcmp(&argv[0][1],"mz80") == 0 ) {
                    c_cpu = CPU_Z80;
                } else if ( strcmp(&argv[0][1],"mz80n") == 0 ) {
                    c_cpu = CPU_Z80N;
                } else if ( strcmp(&argv[0][1],"mz180") == 0 ) {
                    c_cpu = CPU_Z180;
                } else if ( strcmp(&argv[0][1],"mr2ka") == 0 ) {
                    c_cpu = CPU_R2KA;
                } else if ( strcmp(&argv[0][1],"mr3k") == 0 ) {
                    c_cpu = CPU_R3K;
                } else if ( strcmp(&argv[0][1],"mr4k") == 0 ) {
                    c_cpu = CPU_R4K;
                } else if ( strcmp(&argv[0][1],"mr5k") == 0 ) {
                    c_cpu = CPU_R4K;
                } else if ( strcmp(&argv[0][1],"mr6k") == 0 ) {
                    c_cpu = CPU_R6K;
                } else if ( strcmp(&argv[0][1],"mr800") == 0 ) {
                    c_cpu = CPU_R800;
                } else if ( strcmp(&argv[0][1],"mgbz80") == 0 ) {
                    c_cpu = CPU_GBZ80;
                } else if ( strcmp(&argv[0][1],"m8080") == 0 ) {
                    c_cpu = CPU_8080;
                } else if ( strcmp(&argv[0][1],"m8085") == 0 ) {
                    c_cpu = CPU_8085;
                } else if ( strcmp(&argv[0][1],"mvm1") == 0 ) {
                    c_cpu = CPU_KR580VM1;
                } else if ( strcmp(&argv[0][1],"mez80_z80") == 0 ) {
                    c_cpu = CPU_EZ80;
                    c_adl_mode = 0;
                } else if ( strcmp(&argv[0][1],"mez80") == 0 ) {
                    c_cpu = CPU_EZ80;
                    c_adl_mode = 1;
                } else if ( strcmp(&argv[0][1],"mkc160") == 0 ) {
                    c_cpu = CPU_KC160;
                } else if ( strcmp(&argv[0][1],"mkc160_z80") == 0 ) {
                    c_cpu = CPU_KC160_Z80;
                } else {
                    printf("Unknown CPU: %s\n",&argv[0][2]);
                }
                break;
            }
        } else {
            FILE *fp;
            
            if ( strcmp(argv[1],"-") == 0  ) {
                fp = stdin;
            } else {
                fp = fopen(argv[1],"rb");
            }

            if ( fp != NULL ) {
                size_t amount;

                if ( start < 0 ) {
                    start = 0;
                }
                amount = end - start;

                fseek(fp, start - org + skip, SEEK_SET);
                size_t r = fread(mem + (start % BUFF_SIZE), sizeof(char), (amount % BUFF_SIZE), fp);
                loaded = 1;
                fclose(fp);
                if (r < amount)
                {
                    amount = r;
                }
                end = start + (int)amount;
            } else {
                fprintf(stderr, "Cannot load file '%s'\n",argv[1]);
            }
            argc--; argv++;
        }
    }
    if ( loaded ) {
        disassemble_loop(start,end);
    } else {
        usage(program);
    }
    exit(0);
}

static void disassemble_loop(int start, int end)
{
    static char buf[16384];
    int start2 = start;
    const char *last_src_file = NULL;
    int last_src_line = -1;

    while ( start2 < end ) {
        if (c_source) {
            const char *filename = NULL;
            int lineno = 0;
            if (debug_find_source_location(start2, &filename, &lineno) >= 0) {
                if (filename != last_src_file || lineno != last_src_line) {
                    const char *src = get_source_line(filename, lineno);
                    if (src)
                        printf("; %s:%d: %s\n", filename, lineno, src);
                    last_src_file = filename;
                    last_src_line = lineno;
                }
            }
        }
        start2 += disassemble2(start2, buf, sizeof(buf), 0);
        if (!c_autolabel) {
            printf("%s\n",buf);
        }
    }

    if ( c_autolabel ) {
        start2 = start;
        while ( start2 < end ) {
            start2 += disassemble2(start2, buf, sizeof(buf), 0);
            printf("%s\n",buf);
        }
    }
}


uint8_t get_memory(uint32_t pc, memtype type)
{
    return mem[pc % BUFF_SIZE] ^ inverted;
}

int israbbit4k(void)
{
    return c_cpu & (CPU_R4K|CPU_R6K);
}

int israbbit6k(void)
{
    return c_cpu & (CPU_R6K);
}
