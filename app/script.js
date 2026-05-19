const themeToggle = document.querySelector(".theme-toggle");
const toggleIcon = document.querySelector(".toggle-icon");
const deployButton = document.querySelector("#deployButton");
const deployStatus = document.querySelector("#deployStatus");
const terminalOutput = document.querySelector("#terminalOutput");
const metricValues = document.querySelectorAll(".metric-value");
const stackCards = document.querySelectorAll(".stack-card");
const stackNote = document.querySelector("#stackNote");

const savedTheme = localStorage.getItem("theme");

if (savedTheme === "dark") {
  document.body.classList.add("dark");
  toggleIcon.textContent = "Dark";
}

themeToggle.addEventListener("click", () => {
  document.body.classList.toggle("dark");
  const isDark = document.body.classList.contains("dark");
  toggleIcon.textContent = isDark ? "Dark" : "Light";
  localStorage.setItem("theme", isDark ? "dark" : "light");
});

const animateCounter = (element) => {
  const target = Number(element.dataset.target);
  const duration = 1200;
  const startedAt = performance.now();

  const tick = (now) => {
    const progress = Math.min((now - startedAt) / duration, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    element.textContent = Math.round(target * eased);

    if (progress < 1) {
      requestAnimationFrame(tick);
    }
  };

  requestAnimationFrame(tick);
};

const metricObserver = new IntersectionObserver((entries, observer) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      animateCounter(entry.target);
      observer.unobserve(entry.target);
    }
  });
}, { threshold: 0.55 });

metricValues.forEach((value) => metricObserver.observe(value));

deployButton.addEventListener("click", () => {
  const steps = [
    "$ git pull origin main",
    "$ docker build -t dynamic-web-hosting .",
    "$ jenkins deploy --env production",
    "$ aws sync app/ s3://hosting-bucket",
    "Deployment completed with zero downtime."
  ];

  deployButton.disabled = true;
  deployButton.textContent = "Deploying...";
  deployStatus.textContent = "Deployment Running";
  terminalOutput.innerHTML = "";

  steps.forEach((step, index) => {
    setTimeout(() => {
      const line = document.createElement("p");
      line.textContent = step;

      if (index === steps.length - 1) {
        line.classList.add("success");
        deployStatus.textContent = "Successfully Deployed";
        deployButton.disabled = false;
        deployButton.textContent = "Run Demo Deploy";
      }

      terminalOutput.appendChild(line);
    }, index * 650);
  });
});

stackCards.forEach((card) => {
  card.addEventListener("click", () => {
    stackCards.forEach((item) => item.classList.remove("active"));
    card.classList.add("active");
    stackNote.textContent = card.dataset.stack;
  });
});
