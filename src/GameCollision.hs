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
import Player (Player, pPosition, addScoreToPlayer, damagePlayer, addHealthToPlayer)
import Asteroid (Asteroid(Asteroid), aPosition, aWidth)
import HealthPackage (HealthPackage(HealthPackage), hPosition, hWidth)
import Projectile (Projectile, rPosition)
import Enemy (Enemy, ePosition)
import Data.List ((\\), deleteFirstsBy)
import System.Random (StdGen, randomR)

--import Data.Function (on)
--(/.) = (/) `on` fromIntegral -- divides two Integrals as Floats

-- | Collision between asteroids and projectiles
handleProjectilesAsteroidsCollision :: GameState -> GameState
handleProjectilesAsteroidsCollision game =
        game { obstaclesAsteroids = smallerAsteroidsFromBigger ++  map (\x-> snd x) remaindRegularAsteroids 
             , playerProjectiles = map (\x-> snd x) remaindProjectiles
             , player = addScoreToPlayer score (player game)
             }
        where
        asteroids = zip [1..] $ obstaclesAsteroids game
        projectiles =zip [1..] $ playerProjectiles game 
        asteroidProjectilesList = [(a,p) | a <- asteroids, p <- projectiles]
        asteroidProjectilesListFiltered = filter (\x -> checkForAsteoridProjectileCollision  (snd ( fst x)) (snd ( snd x))) asteroidProjectilesList
        asteroidIndicesForRemove = returnAsteroidIndices asteroidProjectilesList asteroidProjectilesListFiltered
        projectileIndicesForRemove = returnProjectileIndices asteroidProjectilesList asteroidProjectilesListFiltered
        remaindRegularAsteroids = filter (\x->  (elem (fst x) asteroidIndicesForRemove) == False) asteroids
        bigAsteroidsForRemoveIndices = filter (\x->  (elem (fst x) asteroidIndicesForRemove) == True && aWidth (snd x) == widthAsteroidBig) asteroids
        bigAsteroidsForRemove = map (\x -> (snd x)) bigAsteroidsForRemoveIndices
        gen = generator game
        (speedX1, gen') = randomR (lowestAsteroidSpeedX, highestAsteroidSpeedX) gen ::(Float, StdGen)
        (speedY1, gen'') = randomR (lowestAsteroidSpeedY,highestAsteroidSpeedY) gen' ::(Float, StdGen)
        (speedX2, gen''') = randomR (lowestAsteroidSpeedX, highestAsteroidSpeedX) gen'' ::(Float, StdGen)
        (speedY2, gen'''') = randomR (lowestAsteroidSpeedY,highestAsteroidSpeedY) gen''' ::(Float, StdGen)
        (deg, gen''''') = randomR (15,30) gen'''' ::(Float, StdGen)
        smallerAsteroidsFromBigger = foldl (\acc x ->  (Asteroid (aPosition x) widthAsteroidSmall (speedX1,speedY1) deg (sAsteroidSpriteSmall (sprites game))) : (Asteroid (aPosition x) widthAsteroidSmall ((-speedX1),speedY2) deg (sAsteroidSpriteSmall (sprites game))) : acc) [] bigAsteroidsForRemove
        remaindProjectiles = filter (\x-> (elem (fst x) projectileIndicesForRemove) == False) projectiles
        score = length asteroidIndicesForRemove * asteroidDestructionScore


checkForAsteoridProjectileCollision :: Asteroid -> Projectile -> Bool
checkForAsteoridProjectileCollision asteroid projectile = centerDistance > radiusSum
        where
        (ax, ay) = aPosition asteroid
        aw = aWidth asteroid / 2 --asteroid radius
        (px, py) = rPosition projectile
        pw = projectileRadius
        centerDistance = (ax-px)^2 + (ay-py)^2
        radiusSum = (aw + pw)^2

returnAsteroidIndices :: [((Int , Asteroid),(Int, Projectile))] -> [((Int , Asteroid),(Int, Projectile))]->[Int]
returnAsteroidIndices  unfilteredList filteredList = asteroidIndices
        where 
        asteroidsForRemoving = filter (\x-> (elem x filteredList) == False) unfilteredList
        asteroidIndices = foldl (\acc x -> (fst ( fst x)) : acc) [] asteroidsForRemoving

returnProjectileIndices :: [((Int , Asteroid),(Int, Projectile))] -> [((Int , Asteroid),(Int, Projectile))]->[Int]
returnProjectileIndices  unfilteredList filteredList = projectileIndices
        where 
        projectilesForRemoving = filter (\x-> (elem x filteredList) == False) unfilteredList
        projectileIndices = foldl (\acc x -> (fst (snd x)) : acc) [] projectilesForRemoving


-- | Checks if there is collision between given circle and rectangle
circleRectangleCollision :: (Float,Float) -- ^ Circle center
                         -> (Float) -- ^ Circle radius
                         -> (Float,Float) -- ^ Rectangle center
                         -> (Float,Float) -- ^ Rectangle width and height
                         -> Bool -- ^ Result
circleRectangleCollision (cx,cy) cr (rx,ry) (rw,rh) =
  if (distanceX > (rw2+cr)) then False
  else if (distanceY > (rh2+cr)) then False
  else if (distanceX <= rw2) then True
  else if (distanceY <= rh2) then True
  else ( (square(distanceX-rw2) + square(distanceY-rh2)) <= (square cr) )
  where 
    rw2 = rw / 2.0
    rh2 = rh / 2.0
    distanceX = abs (cx-rx)
    distanceY = abs (cy-ry)
    square :: Float -> Float
    square x = x * x

-- | Collision between asteroids and player
handlePlayerAsteroidsCollision :: GameState -> GameState
handlePlayerAsteroidsCollision game =
  game { player = damagePlayer totalDamage (player game) 
       , obstaclesAsteroids = notCollidedAsteroids
       }
  where
  asteroids = obstaclesAsteroids game
  notCollidedAsteroids = filter (not . (checkForPlayerAsteroidCollision' (player game)) ) asteroids  
  totalDamage = ((length asteroids) - (length notCollidedAsteroids)) * asteroidDamageToPlayer

-- | Checks if there is collision between a single asteroid and player
-- Asteroid is treated as a circle and Player is treated as a rectangle
checkForPlayerAsteroidCollision :: Player -> Asteroid -> Bool
checkForPlayerAsteroidCollision player asteroid = 
  circleRectangleCollision (ax,ay) ar (px,py) (pw,ph)
  where
    (ax, ay) = aPosition asteroid -- asteroid center
    ar = aWidth asteroid / 2 - spriteCorrection -- asteroid (circle) radius
    (px, py') = pPosition player
    py = (shipSizeHt - shipSizeHb) / 2 + py' -- actual center of spaceship rectangle
    pw = shipSizeWh * 2  -- spaceship's width
    ph = (shipSizeHt + shipSizeHb) -- spaceship's height
    spriteCorrection = 5 -- wiggle room for sprites not being perfect circle and rectangle

-- | Checks if there is collision between a single asteroid and player
-- Asteroid is treated as a circle and Player is treated as a polygon
checkForPlayerAsteroidCollision' :: Player -> Asteroid -> Bool
checkForPlayerAsteroidCollision' player asteroid =
  circleIntersectingPoly ((ax,ay),ar) poly
  where
    (ax, ay) = aPosition asteroid -- asteroid center
    ar = (aWidth asteroid) / 2 -- asteroid (circle) radius
    (px,py) = pPosition player
    pw = shipSizeWh * 2  -- spaceship's width
    ph = shipSizeHt + shipSizeHb + shipSizeHbTail -- spaceship's height
    pw0 = fromIntegral imageShipWidth
    ph0 = fromIntegral imageShipHeight
    poly = polyFrom $ translatePoly px py $ scalePoly (pw/pw0) (ph/ph0) $ spaceshipObject

-- | Collision between enemies and projectiles
handleEnemiesProjectilesCollision :: GameState -> GameState
handleEnemiesProjectilesCollision game =
  game { enemies = map snd remainingEnemies
       , playerProjectiles = map snd remainingProjectiles
       , player = addScoreToPlayer score (player game)
       }
  where
    indexedEnemies = zip [1..] (enemies game)
    indexedProjectiles = zip [1..] (playerProjectiles game)
    pairsEnemiesProjectiles = [(e,p) | e <- indexedEnemies, p <- indexedProjectiles]
    collidedPairs = filter (\x -> checkForEnemiesProjectilesCollision' (snd(fst x)) (snd (snd x))) pairsEnemiesProjectiles
    collidedEnemies = map fst collidedPairs
    collidedProjectiles = map snd collidedPairs 
    remainingEnemies = deleteFirstsBy sameIndex indexedEnemies collidedEnemies
    remainingProjectiles = deleteFirstsBy sameIndex indexedProjectiles collidedProjectiles
    score = ((length indexedEnemies) - (length remainingEnemies)) * enemyDestructionScore
    sameIndex :: (Int,a) -> (Int,a) -> Bool
    sameIndex (i1,_) (i2,_) = (i1==i2)


-- | Checks if there is collision between an enemy and a projectile
-- Projectile is treated as a circle and Enemy is treated as a rectangle
checkForEnemiesProjectilesCollision :: Enemy -> Projectile -> Bool
checkForEnemiesProjectilesCollision enemy projectile = 
  circleRectangleCollision (px,py) pr (ex,ey) (ew,eh)
  where
    (px,py) = rPosition projectile
    pr = projectileRadius
    (ex,ey) = ePosition enemy
    (ew,eh) = (enemySizeW - spriteCorrection, enemySizeH - spriteCorrection)
    spriteCorrection = 5 -- wiggle room for sprites not being perfect circle and rectangle
    
-- | Checks if there is collision between an enemy and a projectile
-- Projectile is treated as a circle and Enemy is treated as a polygon
checkForEnemiesProjectilesCollision' :: Enemy -> Projectile -> Bool
checkForEnemiesProjectilesCollision' enemy projectile = 
  circleIntersectingPoly ((px,py),pr) poly
  where
    (px,py) = rPosition projectile
    pr = projectileRadius
    (ex,ey) = ePosition enemy
    (ew,eh) = (enemySizeW, enemySizeH)
    (ew0,eh0) = (fromIntegral imageEnemyWidth, fromIntegral imageEnemyHeight)
    poly = polyFrom $ translatePoly ex ey $ scalePoly (ew/ew0) (eh/eh0) $ enemyObject

-- | Collision between player and enemy projectiles
handlePlayerProjectilesCollision :: GameState -> GameState
handlePlayerProjectilesCollision game = 
  game { player = damagePlayer totalDamage (player game)
       , enemyProjectiles = notCollidedProjectiles
       }
  where 
    projectiles = enemyProjectiles game
    notCollidedProjectiles = filter (not . (checkForPlayerProjectilesCollision' (player game))) projectiles  
    totalDamage = ((length projectiles) - (length notCollidedProjectiles)) * enemyProjectileDamageToPlayer


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

-- | Checks if there is collision between the player and a projectile
-- Projectile is treated as a circle and Player is treated as a rectangle
checkForPlayerProjectilesCollision :: Player -> Projectile -> Bool
checkForPlayerProjectilesCollision player projectile = 
  circleRectangleCollision (rx,ry) rr (px,py) (pw,ph)
  where
    (rx,ry) = rPosition projectile
    rr = projectileRadius
    (px, py') = pPosition player
    py = (shipSizeHt - shipSizeHb) / 2 + py' -- actual center of spaceship rectangle
    pw = shipSizeWh * 2 - spriteCorrection  -- spaceship's width
    ph = (shipSizeHt + shipSizeHb) - (spriteCorrection * 2) -- spaceship's height
    spriteCorrection = 5 -- wiggle room for sprites not being perfect circle and rectangle    
    
-- | Checks if there is collision between the player and a projectile
-- Projectile is treated as a circle and Player is treated as a polygon
checkForPlayerProjectilesCollision' :: Player -> Projectile -> Bool
checkForPlayerProjectilesCollision' player projectile = 
  circleIntersectingPoly ((rx,ry),rr) poly
  where
    (rx,ry) = rPosition projectile
    rr = projectileRadius
    (px,py) = pPosition player
    pw = shipSizeWh * 2
    ph = shipSizeHt + shipSizeHb + shipSizeHbTail
    pw0 = fromIntegral imageShipWidth
    ph0 = fromIntegral imageShipHeight
    poly = polyFrom $ translatePoly px py $ scalePoly (pw/pw0) (ph/ph0) $ spaceshipObject
    
-- | Checks if there is collision between the player and a health package
-- package is treated as a circle and Player is treated as a polygon
checkForPlayerHealthPackagesCollision :: Player -> HealthPackage -> Bool
checkForPlayerHealthPackagesCollision player package = 
  circleIntersectingPoly ((rx,ry),rr) poly
  where
    (rx,ry) = hPosition package
    rr = hWidth package --radius
    (px,py) = pPosition player
    pw = shipSizeWh * 2
    ph = shipSizeHt + shipSizeHb + shipSizeHbTail
    pw0 = fromIntegral imageShipWidth
    ph0 = fromIntegral imageShipHeight
    poly = polyFrom $ translatePoly px py $ scalePoly (pw/pw0) (ph/ph0) $ spaceshipObject