module GameState where

import Constants
import SpriteCache (SpriteCache, loadAllSprites, sSpaceshipSprites)
import Player (Player, initialPlayerState)
import Asteroid (Asteroid)
import Projectile (Projectile)
import Enemy (Enemy)
import HealthPackage (HealthPackage)
import Graphics.Gloss.Interface.Pure.Game (Key)
import Data.Set (Set, empty)
import System.Random (StdGen, mkStdGen)

-- | Data describing the state of the game. 
data GameState = Game                 -- Game in progress
  { player :: Player                  -- state of the player
  , enemies :: [Enemy]                -- list of enemies
  , obstaclesAsteroids :: [Asteroid]  -- list of obstcales
  , playerProjectiles :: [Projectile] -- list of projectiles fired by the player
  , enemyProjectiles :: [Projectile]  -- list of projectiles fired by the enemies
  , healthPackages :: [HealthPackage] -- list of current health packages
  , timeToAddNewEnemy :: Float        -- time left until a new enemy should be added
  , scoreForAddingHealthPackage :: Int  -- number of points needed for health packages appearing
  , keysPressed :: Set Key            -- keeps track of all keys currently held down
  , paused :: Bool                    -- shows if the game is currently paused
  , showDebug :: Bool                 -- if true debug info is shown on screen
  , generator :: StdGen               -- seed for random numbers
  , sprites :: SpriteCache            -- cache with all game spirtes
  }
  | WelcomeScreen                     -- Program's strating screen
  { keysPressed :: Set Key
  , sprites :: SpriteCache
  } 
  | GameOver                          -- Screen show after player's death
  { keysPressed :: Set Key
  , sprites :: SpriteCache
  , score :: Int                      -- player's score from game
  }

-- | The starting state for the game.
initialState :: GameState
initialState = WelcomeScreen
  { keysPressed = empty
  , sprites = loadAllSprites
  }

-- | Transfering loaded sprites into GameState
initialLoadedGameState :: SpriteCache -> GameState
initialLoadedGameState loadedSprites = Game  
  { player = initialPlayerState (sSpaceshipSprites loadedSprites)
  , enemies = []
  , obstaclesAsteroids = []
  , playerProjectiles = []
  , enemyProjectiles = []
  , healthPackages = []
  , timeToAddNewEnemy = enemySpawnTime
  , scoreForAddingHealthPackage = scoreImprovementForHealthPackageAppearing
  , keysPressed = empty
  , paused = False
  , showDebug = False
  , generator = mkStdGen(23456)
  , sprites = loadedSprites
  }
