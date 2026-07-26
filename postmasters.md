sudo tee /etc/postfix/virtual_mailboxes >/dev/null <<'EOF'
postmaster@fastping.it.com           fastping.it.com/postmaster
you@fastping.it.com                  fastping.it.com/you

postmaster@litehaus.online           litehaus.online/postmaster
you@litehaus.online                  litehaus.online/you

postmaster@cdnedu.online             cdnedu.online/postmaster
you@cdnedu.online                    cdnedu.online/you

blair@blairboulevard.online     blairboulevard.online/blair
you@blairboulevard.online            blairboulevard.online/you

postmaster@analoglogic.blog          analoglogic.blog/postmaster
you@analoglogic.blog                 analoglogic.blog/you

traci@forher.website            forher.website/traci
you@forher.website                   forher.website/you

tom@ryomodular.com            ryomodular.com/tom
you@ryomodular.com                   ryomodular.com/you

wofl@showsome.skin             showsome.skin/wofl
you@showsome.skin                    showsome.skin/you
EOF

sudo postmap /etc/postfix/virtual_mailboxes
