sudo tee /etc/postfix/virtual\_mailboxes >/dev/null <<'EOF'
postmaster@fastping.it.com           fastping.it.com/postmaster
you@fastping.it.com                  fastping.it.com/you

postmaster@litehaus.online           litehaus.online/postmaster
you@litehaus.online                  litehaus.online/you

blair@blairboulevard.website    blairboulevard.website/blair
you@blairboulevard.website            blairboulevard.website/you

postmaster@analoglogic.blog          analoglogic.blog/postmaster
you@analoglogic.blog                 analoglogic.blog/you

tom@ryomodular.com            ryomodular.com/tom
you@ryomodular.com                   ryomodular.com/you

wofl@showsome.skin             showsome.skin/wofl
you@showsome.skin                    showsome.skin/you
EOF

sudo postmap /etc/postfix/virtual\_mailboxes

