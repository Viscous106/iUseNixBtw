# ~/.config/tmuxifier/layouts/openwisp-controller.session.sh

session_root "$HOME/Viscous/gsoc/openwisp-controller.git/master"

if initialize_session "openwisp-controller"; then
  # Since new_window is unstable on this system, we'll use the
  # single, default window created by tmux to run the server command.
  run_cmd "source venv/bin/activate && cd tests && python manage.py runserver 0.0.0.0:8000"
fi

finalize_and_go_to_session
