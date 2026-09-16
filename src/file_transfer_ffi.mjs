export function downloadText(filename, contents) {
  const blob = new Blob([contents], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");

  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function chooseJsonFile(onRead, onError) {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = "application/json,.json";

  input.addEventListener("change", async () => {
    const file = input.files?.[0];
    if (!file) return;

    try {
      onRead(await file.text());
    } catch {
      onError();
    }
  });

  input.click();
}
