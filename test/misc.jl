using Gtk

@testset "misc" begin

unhandled = convert(Cint, false)

foo1 = @guarded (x,y) -> x+y
bar1 = @guarded (x,y) -> x+y+k
@guarded foo2(x,y) = x+y
@guarded bar2(x,y) = x+y+k
@guarded function foo3(x,y)
    x+y
end
@guarded function bar3(x,y)
    x+y+k
end
@guarded unhandled function bar4(x,y)
    x+y+k
end

@test foo1(3,5) == 8
@test @test_logs (:warn, "Error in @guarded callback") bar1(3,5) == nothing
@test foo2(3,5) == 8
@test @test_logs (:warn, "Error in @guarded callback") bar2(3,5) == nothing
@test foo3(3,5) == 8
@test @test_logs (:warn, "Error in @guarded callback") bar3(3,5) == nothing
@test @test_logs (:warn, "Error in @guarded callback") bar4(3,5) == unhandled

# Do-block syntax
c = GtkCanvas()
win = GtkWindow(c)
showall(win)
@guarded draw(c) do widget
    error("oops")
end
@test !isempty(c.mouse.ids)  # check storage of signal-handler ids (see GtkReactive)
destroy(win)

@test isa(Gtk.GdkEventKey(), Gtk.GdkEventKey)

# make sure all shown widgets have been destroyed, otherwise the eventloop
# won't stop automatically
for (w,_) in Gtk.shown_widgets
    destroy(w)
end
Gtk.wait_eventloop_stopping()

@testset "Eventloop control" begin
    before = Gtk.auto_idle[]

    Gtk.enable_eventloop(true)
    @test Gtk.is_eventloop_running()

    Gtk.auto_idle[] = true
    Gtk.pause_eventloop() do
        @test !Gtk.is_eventloop_running()
    end
    @test Gtk.is_eventloop_running()

    Gtk.auto_idle[] = false
    Gtk.pause_eventloop() do
        @test Gtk.is_eventloop_running()
    end
    @test Gtk.is_eventloop_running()

    Gtk.pause_eventloop(force = true) do
        @test !Gtk.is_eventloop_running()
    end
    @test Gtk.is_eventloop_running()
    Gtk.enable_eventloop(false, wait_stopped = true)
    @test !Gtk.is_eventloop_running()

    @testset "pause_eventloop: multithreaded code doesn't block" begin
        Gtk.auto_idle[] = true
        Threads.nthreads() < 1 && @warn "Threads.nthreads() == 1. Multithread blocking tests are not effective"

        function multifoo()
            Threads.@threads for _ in 1:Threads.nthreads()
                sleep(0.1)
            end
        end

        @test !Gtk.is_eventloop_running()
        win = Gtk.Window("Multithread test", 400, 300)
        showall(win)
        @test Gtk.is_eventloop_running()
        for i in 1:10
            Gtk.pause_eventloop() do
                @test !Gtk.is_eventloop_running()
                t = @elapsed multifoo() # should take slightly more than 0.1 seconds
                @test t < 4.5 # given the Glib uv_prepare timeout is 5000 ms
            end
        end
        @test Gtk.is_eventloop_running()
        destroy(win)
        Gtk.wait_eventloop_stopping()
    end

    @testset "wait_eventloop_stopping: waits for stop" begin
        c = GtkCanvas()
        win = GtkWindow(c)
        showall(win)
        @test Gtk.is_eventloop_running()
        destroy(win)
        Gtk.wait_eventloop_stopping()
        @test !Gtk.is_eventloop_running()
    end

    @testset "pause_eventloop: doesn't restart a stopping eventloop" begin
        c = GtkCanvas()
        win = GtkWindow(c)
        showall(win)
        @test Gtk.is_eventloop_running()
        destroy(win)
        Gtk.pause_eventloop() do
            @test !Gtk.is_eventloop_running()
        end
        @test !Gtk.is_eventloop_running()
    end

    Gtk.auto_idle[] = before
end

end
