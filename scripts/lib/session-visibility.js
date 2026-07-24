function shouldSuppressSession({ transcriptPath, isInSessionIndex }) {
  const hasTranscript = typeof transcriptPath === "string" && transcriptPath.trim().length > 0;
  return !hasTranscript && !isInSessionIndex;
}

module.exports = {
  shouldSuppressSession,
};
