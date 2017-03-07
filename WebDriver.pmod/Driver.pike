constant IO_ERROR_RETRY_CNT = 10;
string base_url = "http://127.0.0.1:9515";

Protocols.HTTP.Query query = Protocols.HTTP.Query();

protected void create(void|string base_url, void|mapping opt) {
  if (base_url) {
    // werror("Setting base URL: %s\n", base_url);
    this_program::base_url = base_url;
  }
}

.Session session() {
  .Session ret = .Session();
  ret->set_driver(this);
  ret->initiate();
  return ret;
}

object post(string path, void|mapping|string data) {
  if (mappingp(data)) {
    data = Standards.JSON.encode(data);
  }

  mixed err;
  for(int i=0; i < IO_ERROR_RETRY_CNT; i++) {
    err = catch {
	object ret =
	  Protocols.HTTP.do_method("POST",
				   base_url + path,
				   ([ ]),
				   ([
				     "Content-Type" : "application/json;charset=UTF-8",
				     "Connection" : "Keep-Alive",
				   ]),
				   query,
				   data);
	return ret;
      };

    if (search(describe_backtrace(err), "I/O error") == -1) {
      throw(err);
    }
    sleep(1);
  }

}

object delete(string path) {
  for(int i=0; i < IO_ERROR_RETRY_CNT; i++) {
    mixed err = catch {
	object ret =
	  Protocols.HTTP.do_method("DELETE",
				   base_url + path,
				   ([ ]),
				   ([
				     "Content-Type" : "application/json;charset=UTF-8",
				     "Connection" : "Keep-Alive",
				   ]),
				   query);
	return ret;
      };
    if (search(describe_backtrace(err), "I/O error") == -1) {
      throw(err);
    }
    sleep(1);
  }
}

object get(string path) {
  mixed err;
  for(int i=0; i < IO_ERROR_RETRY_CNT; i++) {
    err = catch {
	object ret = Protocols.HTTP.do_method("GET",
					      base_url + path,
					      ([ ]),
					      ([
						"Content-Type" : "application/json;charset=UTF-8",
						"Connection" : "Keep-Alive",
					      ]),
					      query);
	return ret;
      };
    if (search(describe_backtrace(err), "I/O error") == -1) {
      throw(err);
    }
    sleep(1);
  }
  if (err)
    werror("Failed to perform get: %s\n", describe_backtrace(err));
  return UNDEFINED;
}

