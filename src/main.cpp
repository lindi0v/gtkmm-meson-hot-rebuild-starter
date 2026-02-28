#include <gtkmm.h>

using namespace std;

struct Message {
  const string value = "works";
};

class MainWindow : public Gtk::Window
{
public:
  MainWindow();
};

MainWindow::MainWindow()
{
  set_title("App title");
  set_default_size(640, 480);

  auto msg = Message{};
  Gtk::Label* label = new Gtk::Label(format("it {}", msg.value));

  set_child(*label);
}

int main(int argc, char *argv[])
{
  auto app = Gtk::Application::create("app.id");
  return app->make_window_and_run<MainWindow>(argc, argv);
}