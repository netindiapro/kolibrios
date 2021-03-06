
typedef struct 
{
int  w       __attribute__((packed));
int  h       __attribute__((packed));
char *bmp    __attribute__((packed));
char *alpha  __attribute__((packed));
} GB_BMP     __attribute__((packed));


void gb_pixel_set(GB_BMP *b, int x, int y, unsigned c);

int  gb_pixel_get(GB_BMP *b, int x, int y, unsigned *c);

void gb_line(GB_BMP *b, int x1, int y1, int x2, int y2, unsigned c);

void gb_rect(GB_BMP *b, int x, int y, int w, int h, unsigned c);

void gb_bar(GB_BMP *b, int x, int y, int w, int h, unsigned c);

void gb_circle(GB_BMP *b, int x, int y, int r, unsigned c);

void gb_image_set(GB_BMP *b_dest, int x_d, int y_d, GB_BMP *b_src, int x_s, int y_s, int w, int h);

void gb_image_set_t(GB_BMP *b_dest, int x_d, int y_d, GB_BMP *b_src, int x_s, int y_s, int w, int h, unsigned c);
