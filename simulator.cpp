#include "verilated.h"
#include "Vtop.h"
#include <GL/glut.h>
#include <iostream>
#include <thread>
using namespace std;

/*
    Primary testing for the iCE40-6502 SBC project.
    Features USB Bypassed input and VGA rendering.
*/

Vtop* display; // instantiation of the model
uint64_t main_time = 0; // current simulation time

// to wait for the graphics thread to complete initialization
bool gl_setup_complete = false;

// 640X480 VGA sync parameters
const int ACTIVE_WIDTH = 640;
const int TOTAL_WIDTH = 800;
const int ACTIVE_HEIGHT = 480;
const int TOTAL_HEIGHT = 525;

unsigned char graphics_buffer[ACTIVE_WIDTH][ACTIVE_HEIGHT][3];

bool doCpu = false;

// Gets called periodically to update screen
void render(void)
{
    glClear(GL_COLOR_BUFFER_BIT);

    for(int i = 0; i < ACTIVE_WIDTH; i++)
    {
        for(int j = 0; j < ACTIVE_HEIGHT; j++)
        {
            glColor3ub(graphics_buffer[i][j][0], graphics_buffer[i][j][1], graphics_buffer[i][j][2]);
            glRecti(i, j, i + 1, j + 1);
        }
    }
    glFlush();

    // Clock the CPU
    //display->cpu_test_clk = 1;
    //display->eval();
    //display->cpu_test_clk = 0;
    //display->eval();
}

// Timer to periodically update the screen
void glutTimer(int t)
{
    glutPostRedisplay(); // re-renders the screen
    glutTimerFunc(t, glutTimer, t);
}

void keyPress(unsigned char key, int x, int y) {
    if (key == 27) // ESC
    {
        doCpu = true; // We need a CPU tick
    }
}


// Initiate and handle graphics
void graphics_loop(int argc, char** argv)
{
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_SINGLE);
    glutInitWindowSize(ACTIVE_WIDTH, ACTIVE_HEIGHT);
    glutInitWindowPosition(100, 100);
    glutCreateWindow("VGA Simulator");

    glMatrixMode(GL_PROJECTION);
    // Y=0 at top, increasing downward (matches most pixel buffers)
    glOrtho(0, ACTIVE_WIDTH, ACTIVE_HEIGHT, 0, -1, 1);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glutDisplayFunc(render);
    gl_setup_complete = true;
    // re-render every 16ms, around 60Hz
    glutTimerFunc(16, glutTimer, 16);
    glutKeyboardFunc(keyPress);
    glutMainLoop();
}

// Tracking VGA signals
int coord_x = 0;
int coord_y = 0;

// Read VGA outputs and update graphics buffer
void sample_pixel()
{
    coord_x = (coord_x + 1) % TOTAL_WIDTH;
    if (coord_x + 1 == TOTAL_WIDTH)
    {
        coord_y = (coord_y + 1) % TOTAL_HEIGHT;
    }
    
    if(coord_x < ACTIVE_WIDTH && coord_y < ACTIVE_HEIGHT)
    {
        // Updated for unsigned char (0-255 range)
        graphics_buffer[coord_x][coord_y][0] = display->vga_out_r << 5;
        graphics_buffer[coord_x][coord_y][1] = display->vga_out_g << 5;
        graphics_buffer[coord_x][coord_y][2] = display->vga_out_b << 6;
    }
}

// Simulate for a single clock cycle
void tick()
{
    // update simulation time
    main_time++;
    // rising edge
    display->clk_core = 1;
    if (doCpu)
    {
        display->cpu_test_clk = 1;
        doCpu = false;
    }
    display->eval();
    // falling edge
    display->clk_core = 0;
    display->cpu_test_clk = 0;
    display->eval();
}

int main(int argc, char** argv)
{
    // create a new thread for graphics handling
    std::thread thread(graphics_loop, argc, argv);
    // wait for graphics initialization to complete
    while(!gl_setup_complete);

    Verilated::commandArgs(argc, argv); // remember args
    // create the model
    display = new Vtop;

    // cycle accurate simulation loop
    while (!Verilated::gotFinish())
    {
        tick();
        // Timing is a little messed up. In the real hardware the PLL forces the clock to 25.1750mhz for vga_clk_in.
        // For the simulator, the vga_clk_in takes the form of clk_core
        sample_pixel();

        //printf("test: %d\n", display->test);
    }

    display->final();
    delete display;
    return 0;
}