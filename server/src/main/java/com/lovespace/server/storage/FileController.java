package com.lovespace.server.storage;

import com.lovespace.server.api.BusinessException;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/files")
public class FileController {
  private final MediaService mediaService;

  public FileController(MediaService mediaService) {
    this.mediaService = mediaService;
  }

  @PostMapping("/images")
  public Map<String, Object> upload(@RequestPart("file") MultipartFile file, Authentication auth) throws IOException {
    var media = mediaService.upload(auth.getName(), file);
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put("fileID", media.fileId());
    result.put("fileId", media.fileId());
    result.put("tempFileURL", media.url());
    result.put("url", media.url());
    return result;
  }

  @PostMapping("/temp-url")
  public Map<String, Object> tempUrl(@RequestBody Map<String, Object> body, Authentication auth) {
    String fileId = String.valueOf(body.getOrDefault("fileID", body.getOrDefault("fileId", "")));
    if (fileId.isBlank()) throw new BusinessException("缺少文件 ID");
    String url = mediaService.signedUrl(auth.getName(), fileId);
    return Map.of("code", 0, "tempFileURL", url, "url", url);
  }

  @DeleteMapping("/{id}")
  public Map<String, Object> deletePath(@PathVariable String id, Authentication auth) {
    mediaService.delete(auth.getName(), id);
    return Map.of("code", 0);
  }

  @DeleteMapping
  public Map<String, Object> deleteQuery(@RequestParam("fileID") String fileId, Authentication auth) {
    mediaService.delete(auth.getName(), fileId);
    return Map.of("code", 0);
  }
}
