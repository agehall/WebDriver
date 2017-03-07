object driver;
string session_id;

mapping session_capabilities = ([]);

object _session;

protected void create() {
}

protected string _sprintf(int t) {
  return sprintf("Session(%s)", session_id || "not initialized");
}

void set_driver(object driver) {
  this_program::driver = driver;
}

void initiate() {
  mapping data = ([
    "desiredCapabilities" : ([]),
  ]);
  object resp = driver->post("/session",
			     data);
  string tmp = resp->data();

  mapping info = Standards.JSON.decode(tmp);
  session_id = info->sessionId;
  session_capabilities = info->value + ([]);
  _session = this;
}

void end() {
  _session = UNDEFINED;
  driver->delete("/session/" + session_id);
}


/////////////////////////////////////////////////////////////////////
//
// Navigation
//
string get_url() {
  object query = driver->get("/session/" + session_id + "/url");
  string tmp = query->data();
  mapping d = Standards.JSON.decode(tmp);
  return d->value;
}

int set_url(string url) {
  object query = driver->post("/session/" + session_id + "/url",
			      ([
				"url" : url,
			      ]));
  return 0;
}

int back() {
  driver->post("/session/" + session_id + "/back");
  return 0;
}

int forward() {
  driver->post("/session/" + session_id + "/forward");
  return 0;
}

int refresh() {
  driver->post("/session/" + session_id + "/refresh");
return 0;
}

string get_title() {
  object q = driver->get("/session/" + session_id + "/title");
  string tmp = q->data();
  return Standards.JSON.decode(tmp)->value;
}



/////////////////////////////////////////////////////////////////////
//
// Element stuff
//

class Element(string type, string uuid, object session) {
  protected string _sprintf(int t) {
    return "ELEMENT";
  }

  //!
  //!
  void `value=(mixed data) {
    if (!arrayp(data)) {
      data = ({ data });
    }

    object q = driver->post("/session/" + session_id + "/element/" + uuid + "/value",
			    ([
			      "value" : data,
			    ]));
    string d = q->data();
    mapping res = Standards.JSON.decode(d);
  };

  //!
  //!
  string name() {
    object q = driver->get("/session/" + session_id + "/element/" + uuid + "/name");
    string d = q->data();
    if (d[0] != '{') {
      return UNDEFINED;
    }

    mapping res = Standards.JSON.decode(d);
    // werror("res: %O\n", res);
    return res->value;
  }

  //!
  //!
  this_program find_element_by_xpath(string path) {
    return session->find_element_by_xpath(path, uuid);
  }

  //!
  //!
  array(this_program) find_elements_by_xpath(string path) {
    return session->find_elements_by_xpath(path, uuid);
  }

  //!
  //!
  string attribute(string attr_name) {
    object q = driver->get("/session/" + session_id + "/element/" + uuid + "/attribute/" + attr_name);
    string d = q->data();
    mapping res = Standards.JSON.decode(d);
    return res->value;
  }



  //!
  //! Click this element
  int click() {
    object q = driver->post("/session/" + session_id + "/element/" + uuid + "/click");
    string data = q->data();
    mapping res = Standards.JSON.decode(data);
    if (res->status != 0) {
      // werror("Failed to click! %O\n", res);
      m_delete(elements, uuid);
      destruct(this);
      return res->status;
    }
    return 0;
  }

  //!
  //! Fetches text from this element
  string get_text() {
    object q = driver->get(combine_path_unix("/session", session_id, "element", uuid, "text"));
    string data = q->data();
    mapping res = Standards.JSON.decode(data);
    if (res->status != 0) {
      return UNDEFINED;
    }
    return res->value;
  }

  //!
  //! Move the cursor to this element
  int move_to(void|int x, void|int y) {
    return _session->move_to(x, y, uuid);
  }

  mapping location() {
    object q = driver->get("/session/" + session_id + "/element/" + uuid + "/location");
    string data = q->data();

    mapping res = Standards.JSON.decode(data);
    if (res->status != 0) {
      return UNDEFINED;
    }
    return res->value;
  }
}

// Element cache
mapping(string:Element) elements = ([]);

//! Creates an Element object out of the JSON data for an element. If
//! the element is already in the elements cache that object is
//! returned.
protected Element process_element(mapping e) {
  if (elements[e->ELEMENT])
    return elements[e->ELEMENT];
  return Element("ELEMENT", e->ELEMENT, this);
}

//! Locate the first element matching key using the given strategy. If
//! starting_point is given, it will be appended to the URL to allow
//! the search to originate from an element.
Element find_element(string strategy, string key, void|string starting_point) {
  string url = combine_path_unix("/session/", session_id);
  if (starting_point) {
    url = combine_path_unix(url, "element", starting_point);
  }
  url = combine_path_unix(url, "element");


  object q = driver->post(url, ([
			    "using" : strategy,
			    "value" : key,
			  ]));
  string tmp = q->data();
  if (tmp[0] != '{') {
    // werror("Query failed for %q: %q\n", url, tmp);
    return UNDEFINED;
  }
  mapping res = Standards.JSON.decode(tmp);
  if (res->status) {
    // werror("%q\n%O\n", url, res);
    return UNDEFINED;
  }

  Element ret = process_element(res->value);
  return ret;
}

//! Locate the all element matching key using the given strategy. If
//! starting_point is given, it will be appended to the URL to allow
//! the search to originate from an element.
array(Element) find_elements(string strategy, string key, void|string starting_point) {
  string url = combine_path_unix("/session/", session_id);
  if (starting_point) {
    url = combine_path_unix(url, "element", starting_point);
  }
  url = combine_path_unix(url, "elements");

  object q = driver->post(url, ([
			    "using" : strategy,
			    "value" : key,
			  ]));
  string tmp = q->data();
  if (tmp[0] != '{') {
    // werror("Query failed for %q: %q\n", url, tmp);
    return ({});
  }
  mapping res = Standards.JSON.decode(tmp);
  if (res->status) return ({});

  array(Element) ret = process_element(res->value[*]);
  return ret - ({ 0 });
}

Element find_element_by_tag_name(string name) {
  return find_element("tag name", name);
}

Element find_element_by_xpath(string path, void|string starting_point) {
  return find_element("xpath", path, starting_point);
}

array(Element) find_elements_by_tag_name(string name) {
  return find_elements("tag name", name);
}

array(Element) find_elements_by_xpath(string path, void|string starting_point) {
  return find_elements("xpath", path, starting_point);
}

int move_to(void|int x, void|int y, void|string element_uuid) {
  mapping params = ([]);
  if (x) params->xoffset = x;
  if (y) params->yoffset = y;
  if (element_uuid) params->element = element_uuid;

  if (!sizeof(params)) {
    return 13;
  }

  object q = driver->post(combine_path_unix("/session", session_id, "moveto"), params);
  string res = q->data();
  if (!res || !sizeof(res)) return 0;
  mapping ret = Standards.JSON.decode(res);
  // werror("moveto: %O\n", ret);
  return ret->status;
}

//!
int click() {
  object q = driver->post("/session/" + session_id + "/click");
  string data = q->data();
  mapping res = Standards.JSON.decode(data);
  if (res->status != 0) {
    // werror("click: %O\n", res);
    return res->status;
  }
  return 0;
}

//!
//!
int|string title() {
  object q = driver->get("/session/" + session_id + "/title");
  if (!q) return 13;
  string data = q->data();
  mapping res = Standards.JSON.decode(data);
  if (res->status != 0) {
    // werror("click: %O\n", res);
    return res->status;
  }
  return res->value;
}

//!
//! Returns the alert text being displayed or NoAlertPresentError if non is displayed
int|string alert_text() {
  object q = driver->get("/session/" + session_id + "/alert_text");
  string data = q->data();
  mapping res = Standards.JSON.decode(data);
  if (res->status != 0) {
    return res->status;
  }
  return res->value;
}

//!
//! Dismiss any alert.
int dismiss_alert() {
  object q = driver->post("/session/" + session_id + "/dismiss_alert");
  string data = q->data();
  mapping res = Standards.JSON.decode(data);
  if (res->status != 0) {
    return res->status;
  }
  return 0;
}

//!
//!
int timeouts(string what, int timeout) {
  mapping t = ([
    "type" : what,
    "ms"   : timeout,
  ]);
  object q = driver->post("/session/" + session_id + "/timeouts", t);
  string data = q->data();
  mapping res = Standards.JSON.decode(data);
  if (res->status != 0) {
    werror("timeouts(): %O\n", res);
    return res->status;
  }
  return 0;
}
