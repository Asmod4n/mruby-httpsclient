#include <string.h>
#include <mruby.h>
#include <mruby/string.h>
#include <mruby/class.h>
#include <mruby/variable.h>

static size_t
url_strtosize(const char *s, size_t len)
{
    uint64_t v = 0, m = 1;
    const char *p = s + len;

    if (len == 0)
        goto Error;

    while (1) {
        int ch = *--p;
        if (! ('0' <= ch && ch <= '9'))
            goto Error;
        v += (ch - '0') * m;
        if (p == s)
            break;
        m *= 10;
        /* do not even try to overflow */
        if (m == 10000000000000000000ULL)
            goto Error;
    }

    if (v >= SIZE_MAX)
        goto Error;
    return v;

Error:
    return SIZE_MAX;
}

static mrb_value
mrb_url_parse(mrb_state *mrb, mrb_value self)
{
  char *url;
  mrb_int url_len;
  const char *url_end, *token_start, *token_end;
  mrb_value instance;

  mrb_get_args(mrb, "s", &url, &url_len);

  url_end = url + url_len;
  instance = mrb_obj_new(mrb, mrb_class_get(mrb, "URL"), 0, NULL);

  if (url_len >= 8 && memcmp(url, "https://", 8) == 0) {
    mrb_iv_set(mrb, instance,
      mrb_intern_lit(mrb, "scheme"),
      mrb_str_new_static(mrb, url, 5));
    token_start = url + 8;
    mrb_iv_set(mrb, instance,
      mrb_intern_lit(mrb, "port"),
      mrb_fixnum_value(443));
  }
  else
    return mrb_symbol_value(mrb_intern_lit(mrb, "not_https_url"));

  if (token_start == url_end)
    return mrb_symbol_value(mrb_intern_lit(mrb, "host_missing"));

  if (*token_start == '[') {
    ++token_start;
    if ((token_end = memchr(token_start, ']', url_end - token_start)) == NULL)
      return mrb_symbol_value(mrb_intern_lit(mrb, "invalid_ipv6_address"));

    mrb_iv_set(mrb, instance,
      mrb_intern_lit(mrb, "host"),
      mrb_str_new_static(mrb, token_start, token_end - token_start));

    token_start = token_end + 1;
  } else {
    for (token_end = token_start;
        ! (token_end == url_end || *token_end == '/' || *token_end == ':');
        ++token_end)
        ;

    mrb_iv_set(mrb, instance,
      mrb_intern_lit(mrb, "host"),
      mrb_str_new_static(mrb, token_start, token_end - token_start));

    token_start = token_end;
  }
  if (token_start == url_end)
    goto PathOmitted;

  if (*token_start == ':') {
      size_t p;
      ++token_start;
      if ((token_end = memchr(token_start, '/', url_end - token_start)) == NULL)
          token_end = url_end;
      if ((p = url_strtosize(token_start, token_end - token_start)) >= 65535)
          return mrb_symbol_value(mrb_intern_lit(mrb, "port_too_large"));
      mrb_iv_set(mrb, instance,
        mrb_intern_lit(mrb, "port"),
        mrb_fixnum_value(p));
      token_start = token_end;
      if (token_start == url_end)
          goto PathOmitted;
  }

  mrb_iv_set(mrb, instance,
    mrb_intern_lit(mrb, "path"),
    mrb_str_new_static(mrb, token_start, url_end - token_start));

  return instance;

PathOmitted:
  mrb_iv_set(mrb, instance,
    mrb_intern_lit(mrb, "path"),
    mrb_str_new_cstr(mrb, "/"));

  return instance;
}

static mrb_value
mrb_url_scheme(mrb_state *mrb, mrb_value self)
{
  return mrb_iv_get(mrb, self,
    mrb_intern_lit(mrb, "scheme"));
}

static mrb_value
mrb_url_host(mrb_state *mrb, mrb_value self)
{
  return mrb_iv_get(mrb, self,
    mrb_intern_lit(mrb, "host"));
}

static mrb_value
mrb_url_port(mrb_state *mrb, mrb_value self)
{
  return mrb_iv_get(mrb, self,
    mrb_intern_lit(mrb, "port"));
}

static mrb_value
mrb_url_path(mrb_state *mrb, mrb_value self)
{
  return mrb_iv_get(mrb, self,
    mrb_intern_lit(mrb, "path"));
}

void
mrb_httpsclient_gem_init(mrb_state *mrb)
{
  struct RClass *url_class;

  url_class = mrb_define_class(mrb, "URL", mrb->object_class);

  mrb_define_class_method(mrb, url_class, "parse", mrb_url_parse,MRB_ARGS_REQ(1));
  mrb_define_method(mrb, url_class, "scheme", mrb_url_scheme, MRB_ARGS_NONE());
  mrb_define_method(mrb, url_class, "host", mrb_url_host, MRB_ARGS_NONE());
  mrb_define_method(mrb, url_class, "port", mrb_url_port, MRB_ARGS_NONE());
  mrb_define_method(mrb, url_class, "path", mrb_url_path, MRB_ARGS_NONE());
}

void
mrb_httpsclient_gem_final(mrb_state* mrb) {
  /* finalizer */
}
