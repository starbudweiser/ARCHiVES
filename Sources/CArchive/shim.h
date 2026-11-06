// En-tête minimal de libarchive (celui du SDK macOS est absent). Fonctions de /usr/lib/libarchive.2.dylib.
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>

struct archive;
struct archive_entry;

#define ARCHIVE_EOF 1
#define ARCHIVE_OK 0
#define ARCHIVE_RETRY (-10)
#define ARCHIVE_WARN (-20)
#define ARCHIVE_FAILED (-25)
#define ARCHIVE_FATAL (-30)

#define ARCHIVE_EXTRACT_PERM 0x0002
#define ARCHIVE_EXTRACT_TIME 0x0004
#define ARCHIVE_EXTRACT_SECURE_SYMLINKS 0x0100
#define ARCHIVE_EXTRACT_SECURE_NODOTDOT 0x0200
#define ARCHIVE_EXTRACT_SECURE_NOABSOLUTEPATHS 0x10000

#define AE_IFMT 0170000
#define AE_IFREG 0100000
#define AE_IFLNK 0120000
#define AE_IFDIR 0040000

// lecture
struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_support_format_raw(struct archive *);
int archive_read_add_passphrase(struct archive *, const char *);
int archive_read_open_filename(struct archive *, const char *, size_t);
int archive_read_open_filenames(struct archive *, const char **, size_t);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_block(struct archive *, const void **, size_t *, int64_t *);
int archive_read_data_skip(struct archive *);
int archive_read_close(struct archive *);
int archive_read_free(struct archive *);
int64_t archive_filter_bytes(struct archive *, int);

// écriture sur disque (extraction)
struct archive *archive_write_disk_new(void);
int archive_write_disk_set_options(struct archive *, int);
int archive_write_header(struct archive *, struct archive_entry *);
int archive_write_finish_entry(struct archive *);
ssize_t archive_write_data_block(struct archive *, const void *, size_t, int64_t);
ssize_t archive_write_data(struct archive *, const void *, size_t);
int archive_write_close(struct archive *);
int archive_write_free(struct archive *);

// écriture d'archive (compression)
struct archive *archive_write_new(void);
int archive_write_set_format_zip(struct archive *);
int archive_write_set_format_7zip(struct archive *);
int archive_write_set_options(struct archive *, const char *);
int archive_write_open_filename(struct archive *, const char *);

// lecture du disque (métadonnées des fichiers à compresser)
struct archive *archive_read_disk_new(void);
int archive_read_disk_set_symlink_physical(struct archive *);
int archive_read_disk_entry_from_file(struct archive *, struct archive_entry *, int, const struct stat *);

// erreurs
const char *archive_error_string(struct archive *);

// entrées
struct archive_entry *archive_entry_new(void);
void archive_entry_free(struct archive_entry *);
const char *archive_entry_pathname(struct archive_entry *);
const char *archive_entry_pathname_utf8(struct archive_entry *);
void archive_entry_set_pathname(struct archive_entry *, const char *);
void archive_entry_update_pathname_utf8(struct archive_entry *, const char *);
const char *archive_entry_hardlink(struct archive_entry *);
void archive_entry_set_hardlink(struct archive_entry *, const char *);
void archive_entry_copy_sourcepath(struct archive_entry *, const char *);
mode_t archive_entry_filetype(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
int archive_entry_size_is_set(struct archive_entry *);
int archive_entry_is_data_encrypted(struct archive_entry *);
int archive_entry_is_metadata_encrypted(struct archive_entry *);
