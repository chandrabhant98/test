<!DOCTYPE html>
<html>
<head>
  <title>Snake Game</title>
  <style>
    canvas {
      border: solid black 1px;
    }
  </style>
</head>
<body>
  <canvas id="canvas" width="400" height="400"></canvas>
  <script>
    // Initialize canvas and context
    const canvas = document.getElementById("canvas");
    const ctx = canvas.getContext("2d");

    // Initialize game variables
    const blockSize = 10;
    let snake = [
      { x: 10, y: 10 },
      { x: 10, y: 20 },
      { x: 10, y: 30 },
    ];
    let food = { x: 100, y: 100 };
    let direction = "right";
    let score = 0;

    // Draw the snake and food
    function draw() {
      // Clear the canvas
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Draw the snake
      ctx.fillStyle = "green";
      snake.forEach(function (block) {
        ctx.fillRect(block.x, block.y, blockSize, blockSize);
      });

      // Draw the food
      ctx.fillStyle = "red";
      ctx.fillRect(food.x, food.y, blockSize, blockSize);

      // Draw the score
      ctx.fillStyle = "black";
      ctx.font = "20px Arial";
      ctx.fillText("Score: " + score, 10, 30);
    }

    // Move the snake
    function move() {
      // Remove the tail block
      const tail = snake.pop();

      // Calculate the new head block
      let head = { x: snake[0].x, y: snake[0].y };
      switch (direction) {
        case "right":
          head.x += blockSize;
          break;
        case "left":
          head.x -= blockSize;
          break;
        case "up":
          head.y -= blockSize;
          break;
        case "down":
          head.y += blockSize;
          break;
      }

      // Add the new head block
      snake.unshift(head);

      // Check if the snake has collided with the wall or itself
      if (
        head.x < 0 ||
        head.x >= canvas.width ||
        head.y < 0 ||
        head.y >= canvas.height ||
        snake.some(function (block, index) {
          return index !== 0 && block.x === head.x && block.y === head.y;
        })
      ) {
        // Game over
        clearInterval(intervalId);
        alert("Game over!");
      }

      // Check if the snake has eaten the food
      if (head.x === food.x && head.y === food.y) {
        // Add a new block to the snake
        snake.push(tail);

        // Generate new food position
        food.x = Math.floor(Math.random() * canvas.width / blockSize) * blockSize;
        food.y = Math.floor(Math.random() * canvas.height / blockSize) * blockSize;

        // Increment the score
        score++;
      }
    }

    // Handle keyboard input
    document.addEventListener("keydown", function (event) {
      switch (event.key) {
        case "ArrowRight":
          if (direction !== "left") {
            direction = "right";
          }
          break;
        case "ArrowLeft":
          if (direction !== "right") {
            direction = "left";
          }
          break;
        case "ArrowUp":
          if (direction !== "down") {
            direction = "up";
          }
          break;
        case "ArrowDown":
          if (direction !==
