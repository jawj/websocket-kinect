      window.requestAnimationFrame =
          window.requestAnimationFrame ||
          window.webkitRequestAnimationFrame ||
          window.mozRequestAnimationFrame ||
          window.oRequestAnimationFrame ||
          window.msRequestAnimationFrame ||
          (function () {

              var requests = {},
                  TARGET_FPS = 60,
                  raf_handle = 1,
                  timeout_handle = -1;

              function isVisible(element) {
                  return element.offsetWidth > 0 && element.offsetHeight > 0;
              }

              window.requestAnimationFrame = function requestAnimationFrame(callback, element) {
                  var cb_handle = raf_handle;
                  raf_handle = raf_handle + 1;
                  requests[cb_handle] = {callback: callback, element: element};

                  if (timeout_handle === -1) {
                      timeout_handle = setTimeout(function () {
                          var cur_requests = requests,
                              time = +new Date(),
                              keys = Object.keys(cur_requests),
                              len = keys.length,
                              i,
                              request;

                          requests = {};
                          timeout_handle = -1;

                          for (i = 0; i < len; i += 1) {
                              request = cur_requests[keys[i]];
                              if (!request.element || isVisible(request.element)) {
                                  request.callback(time);
                              }
                          }
                      }, 1000 / TARGET_FPS);
                  }

                  return cb_handle;
              };

              window.cancelRequestAnimationFrame = function cancelRequestAnimationFrame(handle) {

                  delete requests[handle];

                  if (Object.keys(requests).length === 0) {
                      clearTimeout(timeout_handle);
                      timeout_handle = -1;
                  }
              };

              return window.requestAnimationFrame;
          }());

      window.cancelRequestAnimationFrame =
          window.cancelRequestAnimationFrame ||
          window.webkitCancelRequestAnimationFrame ||
          window.mozCancelRequestAnimationFrame ||
          window.oCancelRequestAnimationFrame ||
          window.msCancelRequestAnimationFrame;
