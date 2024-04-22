#!/bin/sh
            cd /blog_engine
            echo  | sudo -S tar xfz blog_engine.tar.gz
            sudo mv /blog_engine/blog_engine.tar.gz /blog_engine/releases/0.1.0/
            sudo /blog_engine/bin/blog_engine stop
            sudo /blog_engine/bin/blog_engine migrate
            sudo /blog_engine/bin/blog_engine start
            