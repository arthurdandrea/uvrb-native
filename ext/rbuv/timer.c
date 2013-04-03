#include "timer.h"

VALUE cRbuvTimer;

struct rbuv_timer_s {
  uv_timer_t *uv_handle;
  VALUE cb;
};

/* Allocator/deallocator */
static VALUE rbuv_timer_alloc(VALUE klass);
static void rbuv_timer_mark(rbuv_timer_t *rbuv_timer);
static void rbuv_timer_free(rbuv_timer_t *rbuv_timer);

/* Methods */
static VALUE rbuv_timer_start(VALUE self, VALUE timeout, VALUE repeat);
static VALUE rbuv_timer_stop(VALUE self);
static VALUE rbuv_timer_repeat_get(VALUE self);
static VALUE rbuv_timer_repeat_set(VALUE self, VALUE repeat);

/* Private methods */
static void _uv_timer_on_timeout(uv_timer_t *uv_timer, int status);

void Init_rbuv_timer() {
  cRbuvTimer = rb_define_class_under(mRbuv, "Timer", cRbuvHandle);
  rb_define_alloc_func(cRbuvTimer, rbuv_timer_alloc);

  rb_define_method(cRbuvTimer, "start", rbuv_timer_start, 2);
  rb_define_method(cRbuvTimer, "stop", rbuv_timer_stop, 0);
  rb_define_method(cRbuvTimer, "repeat", rbuv_timer_repeat_get, 0);
  rb_define_method(cRbuvTimer, "repeat=", rbuv_timer_repeat_set, 1);
}

VALUE rbuv_timer_alloc(VALUE klass) {
  rbuv_timer_t *rbuv_timer;
  VALUE timer;

  rbuv_timer = malloc(sizeof(*rbuv_timer));
  rbuv_timer->uv_handle = malloc(sizeof(*rbuv_timer->uv_handle));
  uv_timer_init(uv_default_loop(), rbuv_timer->uv_handle);

  timer = Data_Wrap_Struct(klass, rbuv_timer_mark, rbuv_timer_free, rbuv_timer);
  rbuv_timer->uv_handle->data = (void *)timer;

  return timer;
}

void rbuv_timer_mark(rbuv_timer_t *rbuv_timer) {
  assert(rbuv_timer);
  rb_gc_mark(rbuv_timer->cb);
}

void rbuv_timer_free(rbuv_timer_t *rbuv_timer) {
  assert(rbuv_timer);
  rbuv_handle_close((rbuv_handle_t *)rbuv_timer);
  free(rbuv_timer);
}

/**
 * start the timer.
 * @param timeout the timeout in millisecond.
 * @param repeat the repeat interval in millisecond.
 * @return self
 */
VALUE rbuv_timer_start(VALUE self, VALUE timeout, VALUE repeat) {
  VALUE block;
  uint64_t uv_timeout;
  uint64_t uv_repeat;
  rbuv_timer_t *rbuv_timer;
  
  rb_need_block();
  block = rb_block_proc();
  uv_timeout = NUM2ULL(timeout);
  uv_repeat = NUM2ULL(repeat);
  
  Data_Get_Struct(self, rbuv_timer_t, rbuv_timer);
  rbuv_timer->cb = block;
  
  RBUV_DEBUG_LOG_DETAIL("rbuv_timer: %p, uv_handle: %p, _uv_timer_on_timeout: %p, timer: %ld",
                        rbuv_timer, rbuv_timer->uv_handle, _uv_timer_on_timeout, self);
  uv_timer_start(rbuv_timer->uv_handle, _uv_timer_on_timeout,
                 uv_timeout, uv_repeat);

  return self;
}

/**
 * stop the timer.
 * @return self
 */
VALUE rbuv_timer_stop(VALUE self) {
  rbuv_timer_t *rbuv_timer;

  Data_Get_Struct(self, rbuv_timer_t, rbuv_timer);
  
  uv_timer_stop(rbuv_timer->uv_handle);
  
  return self;
}

VALUE rbuv_timer_repeat_get(VALUE self) {
  rbuv_timer_t *rbuv_timer;
  VALUE repeat;
  
  Data_Get_Struct(self, rbuv_timer_t, rbuv_timer);
  repeat = ULL2NUM(uv_timer_get_repeat(rbuv_timer->uv_handle));
  
  return repeat;
}

VALUE rbuv_timer_repeat_set(VALUE self, VALUE repeat) {
  rbuv_timer_t *rbuv_timer;
  uint64_t uv_repeat;
  
  uv_repeat = NUM2ULL(repeat);
  
  Data_Get_Struct(self, rbuv_timer_t, rbuv_timer);
  
  uv_timer_set_repeat(rbuv_timer->uv_handle, uv_repeat);
  
  return repeat;
}

void _uv_timer_on_timeout(uv_timer_t *uv_timer, int status) {
  VALUE timer;
  rbuv_timer_t *rbuv_timer;
  
  timer = (VALUE)uv_timer->data;
  Data_Get_Struct(timer, struct rbuv_timer_s, rbuv_timer);
  
  rb_funcall(rbuv_timer->cb, id_call, 1, timer);
}