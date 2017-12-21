module Game
  ( run
  ) where

import Graphics.Gloss
--import Graphics.Gloss.Data.ViewPort
import Graphics.Gloss.Interface.Pure.Game
import Data.Set
import Data.Function

(/.) = (/) `on` fromIntegral -- divides two Integrals as Floats

width, height, offset :: Int
width = 400 
height = 600
offset = 100

wallBoundWidth, shipSizeWh, shipSizeHt, shipSizeHb :: Float
wallBoundWidth = 20
shipSizeWh = 15   -- half of spaceship's width
shipSizeHt = 25   -- spaceship's length of front end
shipSizeHb = 15   -- spaceship's length of back end


window :: Display
window = InWindow "SpaceShooter" (width, height) (offset, offset)

background :: Color
background = black

--TODO: replace (Float, Float) with Coordinate and SpeedVector where appropriate

data PlayerState = Player
  { pPosition :: (Float, Float) -- player coordinates
  , pSpeed :: Float             -- player movement speed
  } deriving Show               -- TODO: debug output

data Rocket = Rocket
  { rPosition :: (Float, Float) -- rocket coodrinates
  , rSpeed :: (Float, Float)    -- speed vector
  } deriving Show               -- TODO: debug output


-- | Data describing the state of the game. 
data GameState = Game
  { player :: PlayerState       -- state of the player
  -- enemies :: [Enemy]         -- list of enemies
  -- obstcales :: [Obstacle]    -- list of obstcales
  , playerRockets :: [Rocket]   -- list of rocket fired
  -- enemyRockets :: [Rocket]   -- list of rocket fired
  -- ....
  -- timeFromLastAddedEnemy :: Float 
  , keysPressed :: Set Key      -- keeps track of all keys currently held down
  , paused :: Bool              -- shows if the game is currently paused
  } deriving Show               -- TODO: debug output

-- | The starting state for the game.
initialState :: GameState
initialState = Game
  { player = Player (0,(-150)) 50
  -- enemies = []
  -- obstacle = []
  , playerRockets = []
  -- enemiesRockets = []
  -- timeFromLastAddedEnemy = 0
  , keysPressed = empty
  , paused = False
  }


-- | Produces a Picture of a given Rocket
drawRocket :: Rocket -> Picture
drawRocket rocket =
  translate rx ry $
    color yellow $
      circle 5
    where
      (rx,ry) = rPosition rocket

-- | Convert a game state into a picture.
render :: GameState  -- ^ The game state to render.
       -> Picture   -- ^ A picture of this game state.
render game =
  pictures [walls,spaceship,rockets]
  where
    -- The player
    (px,py) = pPosition $ player game
    w = shipSizeWh
    ht = shipSizeHt
    hb = shipSizeHb
      
    spaceship :: Picture
    spaceship = 
      translate px py $
        color blue $ 
          polygon [(0,ht),(w,-hb),(0,0),(-w,-hb),(0,ht)]

    --  The bottom and top walls.
    wall :: Float -> Picture
    wall offset =
      translate offset 0 $
        color wallColor $
          rectangleSolid wallBoundWidth (fromIntegral height)

    wallColor = greyN 0.5
    walls = pictures [wall (width /. 2), 
                      wall ( (-width) /. 2)]

    -- Player rockets
    rockets :: Picture
    rockets = pictures $ Prelude.map drawRocket (playerRockets game) 



-- | Update the player
updatePlayer :: Set Key -> Float -> PlayerState -> PlayerState
updatePlayer keysPressed seconds player =
  player { pPosition = (nx', ny') }
    where
      (nx, ny) = pPosition player
      w = wallBoundWidth / 2 + shipSizeWh
      
      nx' :: Float
      nx' = 
        if (member (Char 'd') keysPressed) 
          || (member (SpecialKey KeyRight) keysPressed)
        then
          min (nx + seconds * pSpeed player) (width /. 2 - w)
        else if (member (Char 'a') keysPressed)
          || (member (SpecialKey KeyLeft) keysPressed)
        then
          max (nx - seconds * pSpeed player) ((-width) /. 2 + w)
        else 
          nx

      ny' :: Float
      ny' = 
        if (member (Char 'w') keysPressed) 
          || (member (SpecialKey KeyUp) keysPressed)
        then
          min (ny + seconds * pSpeed player) (height /. 2 - shipSizeHt)
        else if (member (Char 's') keysPressed)
          || (member (SpecialKey KeyDown) keysPressed)
        then
          max (ny - seconds * pSpeed player) (-height /. 2 + shipSizeHb)
        else 
          ny

-- | Wrapper: Calls updatePlayer for GameState
updatePlayerInGame :: Float -> GameState -> GameState
updatePlayerInGame seconds game =
  game { player = updatePlayer (keysPressed game) seconds (player game) }

-- | Update a rocket
updateRocket :: Float -> Rocket -> Rocket
updateRocket seconds rocket =
  rocket { rPosition = (nx', ny') }
    where
      (nx,ny) = rPosition rocket
      (sx,sy) = rSpeed rocket
      nx' = nx + seconds * sx
      ny' = ny + seconds * sy

-- | Update all rockets fired by player for GameState
updatePlayerRocketsInGame :: Float -> GameState -> GameState
updatePlayerRocketsInGame seconds game = 
  game { playerRockets = updateAllRockets seconds (playerRockets game) }
    where
      updateAllRockets :: Float -> [Rocket] -> [Rocket]
      updateAllRockets seconds lstR = Prelude.map (updateRocket seconds) lstR 

-- | Adds new rocket when fired
addRocket :: (Float,Float) -> (Float,Float) -> [Rocket] -> [Rocket]
addRocket (px,py) (sx,sy) rockets = (Rocket (px,py) (sx,sy)) : rockets

-- | Player fired a rocket
rocketFiredByPlayer :: GameState -> GameState
rocketFiredByPlayer game = 
  if ( member (SpecialKey KeySpace) (keysPressed game) )
  then
    game { playerRockets = addRocket (pPosition (player game)) (0,100) (playerRockets game) -- FIX: Remove constants for speed from here
         , keysPressed = delete (SpecialKey KeySpace) (keysPressed game) 
         }
  else
    game
    
-- | Checks if a Rocket has exited the screen
rocketInBounds :: Rocket -> Bool
rocketInBounds rocket =
  if ( (ry > yLimit   ) || 
       (ry < (-yLimit)) ||
       (rx > xLimit   ) ||
       (rx < (-xLimit))
     )
  then
    False
  else
    True
  where
    (rx,ry) = rPosition rocket
    yLimit = height /. 2
    xLimit = width /. 2


deleteOutOfBoundsRockets :: [Rocket] -> [Rocket]
deleteOutOfBoundsRockets rockets = Prelude.filter rocketInBounds rockets

deleteRocketsFormGame :: GameState -> GameState
deleteRocketsFormGame game =
  game { playerRockets = deleteOutOfBoundsRockets (playerRockets game) }


-- | Update the game
update :: Float -> GameState -> GameState 
update seconds game = if not (paused game) 
                      then 
                        rocketFiredByPlayer .
                        updatePlayerRocketsInGame seconds . 
                        deleteRocketsFormGame .
                        updatePlayerInGame seconds $ 
                        game
                      else 
                        game


-- | Number of frames to show per second.
fps :: Int
fps = 60


-- | Respond to key events.
handleKeys :: Event -> GameState -> GameState

-- For an 'p' keypress, pause the game
handleKeys (EventKey (Char 'p') Down _ _) game =
  game { paused = not (paused game) }

-- Ignore 'p' keypress release
handleKeys (EventKey (Char 'p') Up _ _) game = game

-- Remember all keys being pressed
handleKeys (EventKey key Down _ _) game =
  game { keysPressed = insert key (keysPressed game) }
  
-- Forget all keys not pressed anymore
handleKeys (EventKey key Up _ _) game =
  game { keysPressed = delete key (keysPressed game) }



-- Do nothing for all other events.
handleKeys _ game = game

run :: IO ()
run = play window background fps initialState render handleKeys update 
