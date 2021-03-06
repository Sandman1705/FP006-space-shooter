module GameCollision
  ( handlePlayerProjectilesCollision
  , handleEnemiesProjectilesCollision
  , handlePlayerAsteroidsCollision
  , handleProjectilesAsteroidsCollision
  , handlePlayerHealthPackageCollision
  ) where

import Constants
import GameState 
import ObjectCollision
import SpriteCache (sAsteroidSpriteSmall)
import Player (Player, addScoreToPlayer, damagePlayer, addHealthToPlayer, pShape)
import Asteroid (Asteroid(Asteroid), aPosition, aWidth)
import HealthPackage (HealthPackage, hPosition)
import Projectile (Projectile, rPosition)
import Enemy (Enemy, eShape)
import Data.List (deleteFirstsBy)
import System.Random (StdGen, randomR)

--import Data.Function (on)
--(/.) = (/) `on` fromIntegral -- divides two Integrals as Floats

square :: (Num a) => a -> a
square x = x*x

-- | Collision between asteroids and projectiles
handleProjectilesAsteroidsCollision :: GameState -> GameState
handleProjectilesAsteroidsCollision game =
        game { obstaclesAsteroids = smallerAsteroidsFromBigger ++  map (\x-> snd x) remaindRegularAsteroids 
             , playerProjectiles = map (\x-> snd x) remaindProjectiles
             , player = addScoreToPlayer extraScore (player game)
             , generator = gen'''''
             }
        where
        asteroids = zip [1..] $ obstaclesAsteroids game
        projectiles =zip [1..] $ playerProjectiles game 
        asteroidProjectilesList = [(a,p) | a <- asteroids, p <- projectiles]
        asteroidProjectilesListFiltered = filter (\x -> checkForAsteoridProjectileCollision  (snd ( fst x)) (snd ( snd x))) asteroidProjectilesList
        asteroidForRemove = map fst asteroidProjectilesListFiltered
        projectileForRemove = map snd asteroidProjectilesListFiltered
        remaindRegularAsteroids = deleteFirstsBy sameIndex asteroids asteroidForRemove
        bigAsteroidsForRemoveIndices = filter (\x -> aWidth (snd x) == widthAsteroidBig) asteroidForRemove
        bigAsteroidsForRemove = map snd bigAsteroidsForRemoveIndices
        gen = generator game
        (speedX1, gen') = randomR (lowestAsteroidSpeedX, highestAsteroidSpeedX) gen ::(Float, StdGen)
        (speedY1, gen'') = randomR (lowestAsteroidSpeedY,highestAsteroidSpeedY) gen' ::(Float, StdGen)
        (speedX2, gen''') = randomR (lowestAsteroidSpeedX, highestAsteroidSpeedX) gen'' ::(Float, StdGen) -- speedX2 is unused
        (speedY2, gen'''') = randomR (lowestAsteroidSpeedY,highestAsteroidSpeedY) gen''' ::(Float, StdGen)
        (deg, gen''''') = randomR (15,30) gen'''' ::(Float, StdGen)
        smallerAsteroidsFromBigger = foldl (\acc x ->  (Asteroid (aPosition x) widthAsteroidSmall (speedX1,speedY1) deg (sAsteroidSpriteSmall (sprites game))) : (Asteroid (aPosition x) widthAsteroidSmall ((-speedX1),speedY2) deg (sAsteroidSpriteSmall (sprites game))) : acc) [] bigAsteroidsForRemove
        remaindProjectiles = deleteFirstsBy sameIndex projectiles projectileForRemove
        extraScore = length asteroidForRemove * asteroidDestructionScore
        sameIndex :: (Int,a) -> (Int,a) -> Bool
        sameIndex (i1,_) (i2,_) = (i1==i2)


checkForAsteoridProjectileCollision :: Asteroid -> Projectile -> Bool
checkForAsteoridProjectileCollision asteroid projectile = centerDistance <= radiusSum
        where
        (ax, ay) = aPosition asteroid
        aw = aWidth asteroid / 2 --asteroid radius
        (px, py) = rPosition projectile
        pw = projectileRadius
        centerDistance = (square (ax-px)) + (square (ay-py))
        radiusSum = (square (aw + pw))


-- | Collision between asteroids and player
handlePlayerAsteroidsCollision :: GameState -> GameState
handlePlayerAsteroidsCollision game =
  game { player = damagePlayer totalDamage (player game) 
       , obstaclesAsteroids = notCollidedAsteroids
       }
  where
  asteroids = obstaclesAsteroids game
  notCollidedAsteroids = filter (not . (checkForPlayerAsteroidCollision (player game)) ) asteroids  
  totalDamage = ((length asteroids) - (length notCollidedAsteroids)) * asteroidDamageToPlayer


-- | Checks if there is collision between a single asteroid and player
-- Asteroid is treated as a circle and Player is treated as a polygon
checkForPlayerAsteroidCollision :: Player -> Asteroid -> Bool
checkForPlayerAsteroidCollision player asteroid =
  circleIntersectingPoly ((ax,ay),ar) (pShape player)
  where
    (ax, ay) = aPosition asteroid -- asteroid center
    ar = (aWidth asteroid) / 2.0 -- asteroid (circle) radius

-- | Collision between enemies and projectiles
handleEnemiesProjectilesCollision :: GameState -> GameState
handleEnemiesProjectilesCollision game =
  game { enemies = map snd remainingEnemies
       , playerProjectiles = map snd remainingProjectiles
       , player = addScoreToPlayer extraScore (player game)
       }
  where
    indexedEnemies = zip [1..] (enemies game)
    indexedProjectiles = zip [1..] (playerProjectiles game)
    pairsEnemiesProjectiles = [(e,p) | e <- indexedEnemies, p <- indexedProjectiles]
    collidedPairs = filter (\x -> checkForEnemiesProjectilesCollision (snd(fst x)) (snd (snd x))) pairsEnemiesProjectiles
    collidedEnemies = map fst collidedPairs
    collidedProjectiles = map snd collidedPairs 
    remainingEnemies = deleteFirstsBy sameIndex indexedEnemies collidedEnemies
    remainingProjectiles = deleteFirstsBy sameIndex indexedProjectiles collidedProjectiles
    extraScore = ((length indexedEnemies) - (length remainingEnemies)) * enemyDestructionScore
    sameIndex :: (Int,a) -> (Int,a) -> Bool
    sameIndex (i1,_) (i2,_) = (i1==i2)

-- | Checks if there is collision between an enemy and a projectile
-- Projectile is treated as a circle and Enemy is treated as a polygon
checkForEnemiesProjectilesCollision :: Enemy -> Projectile -> Bool
checkForEnemiesProjectilesCollision enemy projectile = 
  circleIntersectingPoly ((px,py),pr) (eShape enemy)
  where
    (px,py) = rPosition projectile
    pr = projectileRadius


-- | Collision between player and enemy projectiles
handlePlayerProjectilesCollision :: GameState -> GameState
handlePlayerProjectilesCollision game = 
  game { player = damagePlayer totalDamage (player game)
       , enemyProjectiles = notCollidedProjectiles
       }
  where 
    projectiles = enemyProjectiles game
    notCollidedProjectiles = filter (not . (checkForPlayerProjectilesCollision (player game))) projectiles  
    totalDamage = ((length projectiles) - (length notCollidedProjectiles)) * enemyProjectileDamageToPlayer

-- | Checks if there is collision between the player and a projectile
-- Projectile is treated as a circle and Player is treated as a polygon
checkForPlayerProjectilesCollision :: Player -> Projectile -> Bool
checkForPlayerProjectilesCollision player projectile = 
  circleIntersectingPoly ((rx,ry),rr) (pShape player)
  where
    (rx,ry) = rPosition projectile
    rr = projectileRadius


-- | Collision between player and health packages
handlePlayerHealthPackageCollision :: GameState -> GameState
handlePlayerHealthPackageCollision game = 
  game { player = addHealthToPlayer totalImprovement (player game)
       , healthPackages = notCollidedHP
       }
  where 
    hps = healthPackages game
    notCollidedHP = filter (not . (checkForPlayerHealthPackagesCollision (player game))) hps  
    totalImprovement = ((length hps) - (length notCollidedHP)) * healthImprovementNumber

-- | Checks if there is collision between the player and a health package
-- package is treated as a circle and Player is treated as a polygon
checkForPlayerHealthPackagesCollision :: Player -> HealthPackage -> Bool
checkForPlayerHealthPackagesCollision player package = 
  not (null (poly1 `clipTo` poly2))
  where
   (hx,hy) = hPosition package
   poly1 =  pShape player
   poly2 =  polyFrom $ translatePoly hx hy $ healthPackageObject
