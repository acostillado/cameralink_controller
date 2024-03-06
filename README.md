# cameralink_controller

* Cameralink controller for ultrascale devices

## Block diagram

### Clocking scheme
The design routes the CL clock through a IBUFDS_DIFF_OUT . The positive signal of the differential pair sources a MMCM, and the negative signal is routed to the fabric, where it becomes the data input of the IDDR's, that sample the differential pairs containing the clock and the data. The input clock is sampled to determine the pixel boundaries.  

After that, the data-sampling clock is the one comming out from the MMCM (the fastest one, 3.5X, not 7x as the IDDR allows sampling at both edges). The pixel clock domain is CLK 1X after determining the frame boundaries. 


![Alt text](/doc/diagram_cl.png)