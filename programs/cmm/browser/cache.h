enum {
	PAGE=1, IMG
};

struct _cache
{
	dword current_buf;
	dword current_size;
	collection url;
	collection_int data;
	collection_int size;
	collection_int type;
	void add();
	bool has();
	void clear();
} cache=0;

void _cache::add(dword _url, _data, _size, _type)
{
	dword data_pointer;
	data_pointer = malloc(_size);
	memmov(data_pointer, _data, _size);
	data.add(data_pointer);

	url.add(_url);
	size.add(_size);
	type.add(_type);
}

bool _cache::has(dword _link)
{
	int pos;
	pos = url.get_pos_by_name(_link);
	if (pos != -1) {
		current_buf = data.get(pos);
		current_size = size.get(pos);
		return true;
	}
	return false;
}

void _cache::clear()
{
	url.drop();
	data.drop();
	size.drop();
	current_buf = NULL;
	current_size = NULL;
}