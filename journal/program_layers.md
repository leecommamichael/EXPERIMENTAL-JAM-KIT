Layered Design:

Layers                 | Files                  | Dependencies
================================================================
Platform               | main_entrypoint.odin   | Sugar
-----------------------|------------------------| 
  Framework (Services) | main_framework.odin    | 
  ---------------------|------------------------| 
    Physics            | physics.odin (not yet) | 
    Render             | render.odin            | NGL
    Audio              | audio.odin   (not yet) | 
    Entities           | entity.odin  (not yet) | 
    -------------------|------------------------| 
			Game             | main.odin              | 

