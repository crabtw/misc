#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include <gtk/gtk.h>
#include <JavaScriptCore/JavaScript.h>
#include <webkit2.h>

#define URI_LOGIN       "https://172.16.255.254/auth.html"
#define URI_LOGIN_OK    "http://172.16.255.254/dynUserLogin.html"
#define URI_LOGIN_FAIL  URI_LOGIN
#define URI_STATUS      "https://172.16.255.254/loginStatusTop.html"

#define JS_FILL_DATA \
    "var frame = window.document.getElementsByName('authFrm')[0].contentDocument;" \
    "var form = frame.getElementsByName('standardPass')[0];" \
    "form['uName'].value = '%s';" \
    "form['pass'].value = '%s';" \
    "form.submit();"

#define JS_CHECK_TIME \
    "window.setTimeout(function() { window.location.reload(true); }, 5 * 60 * 1000);" \
    "var frame = window.document.getElementsByName('loginStatus')[0].contentDocument;" \
    "var frameWin = frame.defaultView;" \
    "frameWin.onunload = null;" \
    "frameWin.clearInterval(frameWin.timerID);" \
    "var time = frame.getElementsByName('timeRemaining')[0];" \
    "parseInt(time.value, 10);"

enum AuthStat {
    STAT_TIME,
    STAT_TIME_CHECK,
    STAT_LOGIN,
    STAT_LOGIN_FILL,
    STAT_LOGIN_CHECK
};

static gchar username[10];
static gchar password[50];

static void transit_state(WebKitWebView *view, enum AuthStat *next_stat);

static void destroy_window_cb(GtkWidget* widget, GtkWidget* window) {
    gtk_main_quit();
}

static gboolean close_view_cb(WebKitWebView* view, GtkWidget* window) {
    gtk_widget_destroy(window);
    return TRUE;
}

static gboolean script_dialog_cb(WebKitWebView *view, WebKitScriptDialog* dialog, gpointer _) {
    return TRUE;
}

static void fill_login_data(WebKitWebView *view, GAsyncResult *result, enum AuthStat *next_stat) {
    GError *err = NULL;
    WebKitJavascriptResult *jsdata = webkit_web_view_run_javascript_finish(view, result, &err);

    if (!jsdata) {
        g_printerr("Error running javascript: %s\n", err->message);
        g_error_free(err);
        return;
    }

    webkit_javascript_result_unref(jsdata);
}

static void check_time(WebKitWebView *view, GAsyncResult *result, enum AuthStat *next_stat) {
    GError *err = NULL;
    WebKitJavascriptResult *jsdata = webkit_web_view_run_javascript_finish(view, result, &err);

    if (!jsdata) {
        g_printerr("Error running javascript: %s\n", err->message);
        g_error_free(err);

        *next_stat = STAT_LOGIN;
        transit_state(view, next_stat);

        return;
    }

    JSGlobalContextRef jsctx = webkit_javascript_result_get_global_context(jsdata);
    JSValueRef jsval = webkit_javascript_result_get_value(jsdata);

    if (JSValueIsNumber(jsctx, jsval)) {
        unsigned int time = JSValueToNumber(jsctx, jsval, NULL);
        g_print("Remaining: %u\n", time);

        if (time < 10) {
            *next_stat = STAT_LOGIN;
            transit_state(view, next_stat);
        }
    }

    webkit_javascript_result_unref(jsdata);
}

static void read_str(gchar *buf, size_t size) {
    gchar *s;
    size_t len;

    s = fgets(buf, size, stdin);
    if (s) {
        len = strlen(s);
        if (s[len-1] == '\n') {
            s[len-1] = '\0';
        }
    } else {
        buf[0] = '\0';
    }
}

static void get_userdata(void) {
    struct termios attr;

    g_print("Username: ");
    read_str(username, sizeof(username));
    g_print("Password: ");

    tcgetattr(STDIN_FILENO, &attr);
    attr.c_lflag &= ~ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &attr);

    read_str(password, sizeof(password));

    attr.c_lflag |= ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &attr);

    g_print("\n");
}

static void transit_state(WebKitWebView *view, enum AuthStat *next_stat) {
    const gchar *uri;
    gchar *js;

    uri = webkit_web_view_get_uri(view);
    if (!uri) {
        uri = "";
    }

next:
    switch (*next_stat) {
    case STAT_TIME:
        *next_stat = STAT_TIME_CHECK;
        webkit_web_view_load_uri(view, URI_STATUS);
        break;
    case STAT_TIME_CHECK:
        if (g_strcmp0(uri, URI_STATUS) == 0) {
            webkit_web_view_run_javascript(view, JS_CHECK_TIME, NULL, (GAsyncReadyCallback)check_time, next_stat);
        }
        break;
    case STAT_LOGIN:
        *next_stat = STAT_LOGIN_FILL;
        webkit_web_view_load_uri(view, URI_LOGIN);
        break;
    case STAT_LOGIN_FILL:
        if (g_strcmp0(uri, URI_LOGIN) == 0) {
            *next_stat = STAT_LOGIN_CHECK;
            js = g_strdup_printf(JS_FILL_DATA, username, password);
            webkit_web_view_run_javascript(view, js, NULL, (GAsyncReadyCallback)fill_login_data, next_stat);
            g_free(js);
        }
        break;
    case STAT_LOGIN_CHECK:
        if (g_strcmp0(uri, URI_LOGIN_FAIL) == 0) {
            *next_stat = STAT_LOGIN;
            g_printerr("Login failed\n");
            get_userdata();
            goto next;
        } else if (g_strcmp0(uri, URI_LOGIN_OK) == 0) {
            *next_stat = STAT_TIME;
            goto next;
        }
        break;
    }
}

static void load_changed_cb(WebKitWebView *view, WebKitLoadEvent event, enum AuthStat *next_stat) {
    if (event == WEBKIT_LOAD_FINISHED) {
        transit_state(view, next_stat);
    }
}

int main(int argc, char **argv) {
    enum AuthStat next_stat = STAT_TIME;

    // Initialize GTK+
    gtk_init(&argc, &argv);
    get_userdata();

    // Create an 800x600 window that will contain the browser instance
    GtkWidget *main_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    //gtk_window_set_default_size(GTK_WINDOW(main_window), 800, 600);

    // Create a browser instance
    WebKitWebView *view = WEBKIT_WEB_VIEW(webkit_web_view_new());

    // Set up callbacks so that if either the main window or the browser instance is
    // closed, the program will exit
    g_signal_connect(main_window, "destroy", G_CALLBACK(destroy_window_cb), NULL);
    g_signal_connect(view, "close", G_CALLBACK(close_view_cb), main_window);
    g_signal_connect(view, "script-dialog", G_CALLBACK(script_dialog_cb), NULL);
    g_signal_connect(view, "load-changed", G_CALLBACK(load_changed_cb), &next_stat);

    // Put the scrollable area into the main window
    gtk_container_add(GTK_CONTAINER(main_window), GTK_WIDGET(view));

    // Load a web page into the browser instance
    //WebKitSettings *settings = webkit_web_view_get_settings(view);
    //webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);
    transit_state(view, &next_stat);

    // Make sure that when the browser area becomes visible, it will get mouse
    // and keyboard events
    //gtk_widget_grab_focus(GTK_WIDGET(view));

    // Make sure the main window and all its contents are visible
    //gtk_widget_show_all(main_window);

    // Run the main GTK+ event loop
    gtk_main();

    return 0;
}
