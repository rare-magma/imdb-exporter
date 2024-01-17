.PHONY: install
install:
	@mkdir --parents $${HOME}/.local/bin \
	&& mkdir --parents $${HOME}/.config/systemd/user \
	&& cp imdb_exporter.sh $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/imdb_exporter.sh \
	&& cp --no-clobber imdb_exporter.conf $${HOME}/.config/imdb_exporter.conf \
	&& chmod 400 $${HOME}/.config/imdb_exporter.conf \
	&& cp imdb-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp imdb-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now imdb-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f $${HOME}/.local/bin/imdb_exporter.sh \
	&& rm -f $${HOME}/.config/imdb_exporter.conf \
	&& systemctl --user disable --now imdb-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/imdb-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/imdb-exporter.service
